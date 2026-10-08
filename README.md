# Bad Pods

[Bad Pods](https://github.com/BishopFox/badPods) by Seth Art (Bishop Fox): a collection of
manifests that create pods with elevated privileges (`privileged`, `hostPath`, `hostPID`,
`hostNetwork`, `hostIPC` and combinations), with the post-exploitation steps for each. This
repository turns them into a lab with [Isoloom](https://www.isoloom.com):
[`isoloom.yml`](isoloom.yml) describes one VM that is a single-node Kubernetes cluster (k3s,
[`provision/k3s.sh`](provision/k3s.sh)), set up as Bad Pods' README assumes
([`provision/cluster.sh`](provision/cluster.sh)): a user who may create workloads and exec into
pods in one namespace, and nothing stopping a pod from asking for host access. The manifests are
vendored unchanged in [`badPods/`](badPods).

| Machine | Services |
| --- | --- |
| cluster | SSH 22 (user player / player), Kubernetes API 6443 |

## Run it

```bash
isoloom run vagrant
isoloom test vagrant
```

You are `player`: a bearer token for the API server (in [`provision/tokens.csv`](provision/tokens.csv),
use it against `https://10.60.121.10:6443` from the lab network) bound to a Role that may create
pods, deployments, daemonsets, jobs, cronjobs, replicasets, statefulsets and replication
controllers, and exec into pods, in the namespace `badpods`. The same identity has an
unprivileged shell account on the node (SSH as player / player) with kubectl configured and the
manifests in `~/badPods`. Goal: root on the node, then `/root/flag.txt`; from there, the cluster
(the admin kubeconfig is root-only). About 3 GB of memory for the machine, plus 1 GB for the
controller that runs the checks.

Upstream is a set of manifests, not a running lab: the cluster (k3s v1.36.5, pinned by
checksum), the player's Role and token, the shell account and the flag are this repository's.

Lab guide: Bad Pods' [README](badPods/README.md) and one README per pod in
[`badPods/manifests/`](badPods/manifests), and the blog post
[Bad Pods: Kubernetes Pod Privilege Escalation](https://labs.bishopfox.com/tech-blog/bad-pods-kubernetes-pod-privilege-escalation).
Upstream version and commit: [UPSTREAM.md](UPSTREAM.md).

## Licence

MIT, as Bad Pods ([LICENSE](LICENSE)), copyright Bishop Fox. The cluster runs k3s
(Apache-2.0); the manifests pull `ubuntu` and `raesene/ncat` from Docker Hub. This cluster is
deliberately open to pod escapes: keep it isolated.
