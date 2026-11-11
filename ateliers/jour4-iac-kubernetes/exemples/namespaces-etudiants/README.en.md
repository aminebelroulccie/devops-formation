# One namespace per student, full rights inside it and none outside

_English version · la version française est dans [`README.md`](README.md)_

For a **shared** cluster (the one from [`terraform-kubespray/`](../terraform-kubespray/README.en.md),
or the trainer's kind): every student gets a namespace, a kubeconfig that opens only that
namespace, a quota and default limits. Six students by default (`students.txt`), the Formini
logins `formini-a1` … `formini-b3`.

```
students.txt ──generate.sh──► generated/<login>.yaml ──kubectl apply──► cluster
                                                                            │
                                                     make-kubeconfigs.sh ◄──┘
                                                            │
                                                  kubeconfigs/<login>.conf  → hand to each student
                                                            │
                                                        verify.sh  (auth can-i: yes at home, no elsewhere)
```

| Object created per student | Role |
|----------------------------|------|
| Namespace `<login>` | their space, labelled `student=<login>` |
| ServiceAccount `<login>` | their identity |
| Secret `<login>-token` | durable ServiceAccount token (valid all week, revoked by deleting the Secret) |
| RoleBinding `<login>-admin` → ClusterRole **`admin`** | **full access inside the namespace**: Deployments, StatefulSets, Services, Secrets, ConfigMaps, PVCs, Ingress, Roles and RoleBindings…; **nothing outside**: no reading other namespaces, no nodes, no creating or deleting namespaces, no changing the quota |
| ResourceQuota `quota` | 2 CPU / 4 Gi requests, 4 CPU / 8 Gi limits, 30 pods, 2 NodePorts, 4 PVCs, 10 Gi |
| LimitRange `defaults` | requests and limits applied to containers that declare none (otherwise the quota would reject them) |

Why Kubernetes' built-in ClusterRole `admin` rather than a home-made `*` Role: it is maintained
with Kubernetes releases, it covers everything a developer needs inside a namespace, and it
excludes exactly what a student must not touch (the Namespace itself, ResourceQuotas, LimitRanges).

## Setup (trainer, with the cluster's admin kubeconfig)

```bash
cd ateliers/jour4-iac-kubernetes/exemples/namespaces-etudiants
nano students.txt                      # one login per line
bash generate.sh --apply               # creates the 6 × 6 objects
bash make-kubeconfigs.sh https://<API IP as seen by the students>:6443
bash verify.sh                         # 11 checks per student, all "ok"
```

For the Kubespray cluster on AWS, the API URL is `https://<Elastic IP of node1>:6443` (add it to
`supplementary_addresses_in_ssl_keys` before running Kubespray). For a kind cluster on the
trainer's VM, recreate it with `networking.apiServerAddress: "<VM IP>"` in `kind-config.yaml`,
otherwise the API listens on `127.0.0.1` only.

Then hand each student **their** file, and only theirs:

```bash
scp kubeconfigs/formini-a1.conf devops@<VM of formini-a1>:~/.kube/config
```

## Student side

```bash
kubectl config current-context        # formini-a1
kubectl get pods                      # their default namespace: empty, no error
kubectl get pods -n formini-a2        # Error from server (Forbidden)
kubectl get namespaces                # Forbidden
kubectl apply -k ../go-react/k8s/     # refused: the manifests target the formini-go namespace
```

To deploy the Go + React stack in **their** namespace, a student changes one line of
`k8s/kustomization.yaml` (`namespace: formini-a1`), removes `namespace.yaml` from `resources`,
then `kubectl apply -k`. The two StatefulSets, four Services and ConfigMaps fit in the quota; the
NodePort 30081 Service can only be taken by one student per cluster: the others use
`kubectl port-forward svc/frontend 8081:80` or change `nodePort`.

## What to observe

- **RoleBinding, not ClusterRoleBinding**: the same `admin` ClusterRole bound inside a namespace
  grants rights there only. A ClusterRoleBinding would grant `admin` on the whole cluster.
- **The quota is visible**: `kubectl describe quota` in the namespace shows usage. A
  `kubectl scale --replicas=50` is rejected with an explicit message.
- **The LimitRange makes the quota liveable**: without it, every pod without `resources` would be
  rejected by the `requests.cpu` quota.
- **One token = one Secret**: `kubectl -n formini-a1 delete secret formini-a1-token` revokes
  access immediately; `generate.sh --apply` recreates it (new token, new kubeconfig).
- **No network isolation here**: pods in one namespace can reach those of another by full DNS
  name (`api.formini-a2.svc`). Isolating them needs NetworkPolicies and a CNI that enforces them
  (Calico on Kubespray: yes; kindnet on kind: no).

## Exercises

1. Add a seventh login and rerun the three scripts: nothing changes for the other six
   (`kubectl apply` is idempotent).
2. Replace `admin` with `edit` in the template for one student: what can they no longer do?
   (`kubectl auth can-i create rolebindings`).
3. Add a "deny from other namespaces" NetworkPolicy to the template and test it on the Kubespray
   cluster with `kubectl run -n formini-a2 curl --image=curlimages/curl -- …`.
4. Give the trainer read-only access to every namespace with a ClusterRoleBinding on the `view`
   ClusterRole.

## Clean up

```bash
kubectl delete -f generated/all.yaml       # deletes the namespaces, hence everything inside
rm -rf kubeconfigs/                        # the tokens are worthless now, but do not leave them around
```
