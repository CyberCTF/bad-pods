#!/bin/sh
# The lab's starting point, as Bad Pods' README assumes it: a user who may create pods (and the
# seven other workload types) and exec into them in one namespace, nothing more, on a cluster
# that lets pods ask for host access. The user "player" is that identity twice: a bearer token
# for the API server (provision/tokens.csv, usable from anywhere on the lab network) and an
# unprivileged shell account on the node with kubectl preconfigured and Bad Pods' manifests in
# ~/badPods. The goal is the node: /root/flag.txt is readable by root only.
set -eu
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
TOKEN=$(cut -d, -f1 /etc/rancher/k3s/tokens.csv)

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata: { name: badpods }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: workload-creator, namespace: badpods }
rules:
  - apiGroups: [""]
    resources: [pods, replicationcontrollers]
    verbs: [create, get, list, watch, delete]
  - apiGroups: [""]
    resources: [pods/exec, pods/log]
    verbs: [create, get]
  - apiGroups: [apps]
    resources: [deployments, daemonsets, replicasets, statefulsets]
    verbs: [create, get, list, watch, delete]
  - apiGroups: [batch]
    resources: [jobs, cronjobs]
    verbs: [create, get, list, watch, delete]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: player-workload-creator, namespace: badpods }
subjects: [{ kind: User, name: player, apiGroup: rbac.authorization.k8s.io }]
roleRef: { kind: Role, name: workload-creator, apiGroup: rbac.authorization.k8s.io }
YAML

id player >/dev/null 2>&1 || useradd -m -s /bin/bash player
echo 'player:player' | chpasswd
cat > /etc/ssh/sshd_config.d/10-player.conf <<'SSHD'
Match User player
    PasswordAuthentication yes
    KbdInteractiveAuthentication yes
SSHD
systemctl reload-or-restart ssh 2>/dev/null || systemctl reload-or-restart sshd

H=/home/player
mkdir -p $H/.kube
cat > $H/.kube/config <<KCFG
apiVersion: v1
kind: Config
clusters:
  - name: lab
    cluster: { server: "https://127.0.0.1:6443", insecure-skip-tls-verify: true }
users:
  - name: player
    user: { token: "$TOKEN" }
contexts:
  - name: player
    context: { cluster: lab, user: player, namespace: badpods }
current-context: player
KCFG
rm -rf $H/badPods && cp -r /opt/isoloom/badPods $H/badPods
chown -R player:player $H/.kube $H/badPods
chmod 600 $H/.kube/config
# k3s's kubectl reads /etc/rancher/k3s/k3s.yaml unless KUBECONFIG says otherwise.
for f in .profile .bashrc; do
  grep -q KUBECONFIG "$H/$f" 2>/dev/null || echo 'export KUBECONFIG=$HOME/.kube/config' >> "$H/$f"
done
chown player:player "$H/.profile" "$H/.bashrc"

[ -f /root/flag.txt ] || echo 'badpods{node-root-91fd59c89c1f49e142b945d786cf3ec2}' > /root/flag.txt
chmod 600 /root/flag.txt

echo "player ready: namespace badpods, may create workloads and exec into pods"
