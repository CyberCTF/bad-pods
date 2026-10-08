#!/bin/sh
# Installs a single-node Kubernetes cluster (k3s), pinned by version and SHA-256, without Pod
# Security admission (Bad Pods' prerequisite: nothing stops a pod from asking for host access).
# The API server also reads a static token file (provision/cluster.sh writes it), the player's
# credentials. Traefik and the service load balancer are left out (unused). The admin
# kubeconfig stays root-only: taking it is part of the lab.
set -eu
K3S_VERSION=v1.36.5+k3s1
K3S_SHA256=d73847bcd3c5fccef0115b372e2f9a91f3032dc84bbf71518a4617565294d313
K3S_INSTALL_SHA256=46177d4c99440b4c0311b67233823a8e8a2fc09693f6c89af1a7161e152fbfad
ADDR=10.60.121.10
tag=$(printf %s "$K3S_VERSION" | sed 's/+/%2B/')

command -v curl >/dev/null || { apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install -yq curl; }
mkdir -p /etc/rancher/k3s
[ -f /etc/rancher/k3s/tokens.csv ] || cp /opt/isoloom/provision/tokens.csv /etc/rancher/k3s/tokens.csv
chmod 600 /etc/rancher/k3s/tokens.csv

if [ ! -x /usr/local/bin/k3s ]; then
  curl -fsSL -o /usr/local/bin/k3s "https://github.com/k3s-io/k3s/releases/download/$tag/k3s"
  echo "$K3S_SHA256  /usr/local/bin/k3s" | sha256sum -c -
  chmod 755 /usr/local/bin/k3s
fi
if ! systemctl is-active -q k3s; then
  curl -fsSL -o /tmp/k3s-install.sh "https://raw.githubusercontent.com/k3s-io/k3s/$tag/install.sh"
  echo "$K3S_INSTALL_SHA256  /tmp/k3s-install.sh" | sha256sum -c -
  INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_VERSION="$K3S_VERSION" \
    INSTALL_K3S_EXEC="server --disable traefik --disable servicelb --node-ip $ADDR --tls-san $ADDR --kube-apiserver-arg=token-auth-file=/etc/rancher/k3s/tokens.csv" \
    sh /tmp/k3s-install.sh
  rm -f /tmp/k3s-install.sh
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
i=0
until kubectl get nodes 2>/dev/null | grep -q ' Ready'; do
  i=$((i + 1)); [ $i -lt 90 ] || { echo "k3s node never became Ready"; exit 1; }; sleep 2
done
# k3s creates its add-ons (CoreDNS first) a little after the node is Ready.
i=0
until kubectl -n kube-system get deploy/coredns >/dev/null 2>&1; do
  i=$((i + 1)); [ $i -lt 90 ] || { echo "CoreDNS never deployed"; exit 1; }; sleep 2
done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
echo "k3s $K3S_VERSION ready"
