#!/bin/sh
# The lab's starting point holds: the player's token may create pods and exec into them in the
# badpods namespace, and may not read secrets in kube-system (it is not already an admin).
set -u
cd /opt/isoloom 2>/dev/null || true
T=$(cut -d, -f1 provision/tokens.csv)
can() { # verb resource namespace [subresource] [api group]
  curl -sk --max-time 20 -H "Authorization: Bearer $T" -H 'Content-Type: application/json' \
    -X POST https://cluster:6443/apis/authorization.k8s.io/v1/selfsubjectaccessreviews \
    -d "{\"apiVersion\":\"authorization.k8s.io/v1\",\"kind\":\"SelfSubjectAccessReview\",\"spec\":{\"resourceAttributes\":{\"verb\":\"$1\",\"resource\":\"$2\",\"namespace\":\"$3\",\"subresource\":\"${4:-}\",\"group\":\"${5:-}\"}}}" \
    | grep -q '"allowed": *true'
}
can create pods badpods || { echo "player cannot create pods"; exit 1; }
can create pods badpods exec || { echo "player cannot exec into pods"; exit 1; }
can create daemonsets badpods "" apps || { echo "player cannot create daemonsets"; exit 1; }
if can get secrets kube-system; then echo "player is already privileged"; exit 1; fi
echo "player may create workloads and exec in badpods, nothing in kube-system"
