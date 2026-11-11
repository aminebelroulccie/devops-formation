# Day 4 — Lab: Infrastructure as Code and Kubernetes

_English version · la version française est dans [`README.md`](README.md)_

**Wednesday 11 November 2026 · Formini DevOps Training**

| Part | Time          | Format      | Content                                                     |
|------|---------------|-------------|-------------------------------------------------------------|
| 1    | 10:45 – 12:00 | Individual  | Terraform creates an AWS server, Ansible deploys the application on it |
| 2    | 14:00 – 15:30 | Per team    | Formini Tasks on Kubernetes (kind): deploy, scale, update, roll back |

The solution files are in [`solution/`](solution/). Try without them first,
and look at them once you have been stuck for more than ten minutes.

> **Absolute rule of the day**: everything created on AWS is destroyed with
> `terraform destroy` **before 12:00** (end of part 1) and checked in the
> console. The trainer takes the roll call at 15:30.

---

## Objectives

By the end of the lab, you can:

- write and read a Terraform project (providers, resources, variables, outputs, state);
- run `init → plan → apply → destroy` on AWS while reading the plan;
- configure a server with an idempotent Ansible playbook, without ever logging in by hand;
- deploy an application and its database on Kubernetes with Deployment, StatefulSet, Service, Secret, PVC;
- scale, perform a rolling update with no downtime, and roll back.

## Prerequisites

On your Formini VM (Ubuntu 24.04, user `devops`):

```bash
terraform version     # >= 1.6
ansible --version     # >= 2.14
kubectl version --client
kind version          # >= 0.20
docker ps             # Docker works without sudo
ls ~/.ssh/id_ed25519.pub   # the key from day 1
```

AWS credentials provided by the trainer (one pair per participant):

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="eu-west-3"     # Paris
```

Add these three lines to `~/.bashrc` for the day, and **remove them tonight**.
Never put them in a file inside the repository.

Get the lab material from your clone of the training repository:

```bash
cd ~/formation-devops/ateliers/jour4-iac-kubernetes
cp -r solution/terraform solution/ansible solution/k8s ~/formini-tasks/   # into your application repository
```

(You can also write every file yourself by following the slides: that is the point.)

---

## Part 1 — An AWS server, from zero to the application (10:45 – 12:00)

### 1.1 Read the Terraform project

In `terraform/`, five files:

| File                      | Role                                                           |
|---------------------------|----------------------------------------------------------------|
| `versions.tf`             | Terraform version, AWS provider `~> 5.0`, default tags         |
| `variables.tf`            | Region, first name, instance type, path to the public key      |
| `main.tf`                 | VPC, public subnet, IGW, route table, SG, key pair, Ubuntu 24.04 AMI, instance |
| `outputs.tf`              | Public IP, SSH command, Ansible inventory line                 |
| `user_data.sh`            | First-boot script (hostname, python3)                          |

Before typing a single command, answer in writing:

1. How many `resource` blocks? How many `data` blocks?
2. In what order will Terraform create them, and why?
3. Which ports are open from the Internet?

### 1.2 Prepare the variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars          # owner = "your-first-name"  (lowercase, no accents)
```

Security bonus: replace `ssh_allowed_cidr` with your public IP as a `/32`
(`curl -s ifconfig.me`).

### 1.3 init, plan, apply

```bash
terraform init          # downloads the AWS provider, creates .terraform.lock.hcl
terraform fmt           # formats the code
terraform validate      # checks syntax and references
terraform plan          # READ IT: "Plan: 9 to add, 0 to change, 0 to destroy."
terraform apply         # re-read the plan, type yes
```

Time it: creation takes two to three minutes. Meanwhile, open the AWS console
(Paris region) → EC2 → Instances, and filter by the `Owner` tag.

```bash
terraform output                      # public_ip, ssh, app_url, ansible_inventory
terraform state list                  # the 9 known objects
terraform state show aws_instance.web # everything AWS returned
```

### 1.4 Connect over SSH

```bash
$(terraform output -raw ssh)          # runs the ssh command from the output
# or
ssh -i ~/.ssh/id_ed25519 ubuntu@$(terraform output -raw public_ip)
```

On the server: `hostname`, `cat /var/log/formini-user-data.log`, `docker`
(missing: that is Ansible's job). Log out.

> If the connection is refused during the first minute, the instance is still
> booting. If it stays refused: `terraform state show aws_security_group.web`,
> check port 22 and `ssh_allowed_cidr`.

### 1.5 Ansible: inventory and ping

```bash
cd ../ansible
cp inventory.ini.example inventory.ini
terraform -chdir=../terraform output -raw ansible_inventory   # copy this line into inventory.ini
ansible web -m ping
ansible web -a "uptime"
ansible web -b -m apt -a "name=htop state=present"           # one module, ad hoc, with sudo
```

### 1.6 The playbook

Read `playbook.yml` from start to finish. Spot: `hosts`, `become`, the modules
used, the `notify`/`handlers`, the `tags`, and **how the application gets onto
the server**.

> **Why copy the code instead of pulling the image from the Gitea registry?**
> The `gitea.formini.local:3000` registry is on the classroom network, over HTTP:
> the AWS server cannot reach it. So the playbook copies the application
> repository (with the `Dockerfile` and the `compose.yaml` from day 2) and builds
> the image **on the server**. In production, you would pull the image from a
> reachable registry (ECR, Docker Hub, Gitea exposed over HTTPS).

The playbook looks for the code in `app_src` (by default the
`app/formini-tasks` folder of the training repository). To point it at **your**
repository:

```bash
ansible-playbook playbook.yml -e app_src=$HOME/formini-tasks
```

Run it:

```bash
ansible-playbook playbook.yml --check        # dry run: nothing is changed
ansible-playbook playbook.yml                # for real (3 to 4 minutes)
ansible-playbook playbook.yml                # a second time: changed=0 ?
```

Open `http://<IP>:5000` from the Formini workstation and create a task. Check
`/health` and `/metrics`.

### 1.7 Destroy, verify

```bash
cd ../terraform
terraform destroy          # "Plan: 0 to add, 0 to change, 9 to destroy." → yes
terraform state list       # empty
```

**End-of-part-1 checklist** (actually tick the boxes):

- [ ] `terraform destroy` finished without error (`Destroy complete! Resources: 9 destroyed.`)
- [ ] EC2 console → Instances: no `formini-<first-name>-web` instance (even a "terminated" one disappears within an hour)
- [ ] VPC console: no `formini-<first-name>-vpc` VPC
- [ ] EC2 console → Key pairs: no `formini-<first-name>` key pair
- [ ] EC2 console → Volumes: no orphaned volume
- [ ] `aws ec2 describe-instances --filters Name=tag:Owner,Values=<first-name>` returns nothing (if the CLI is installed)

### Part 1 bonus

- Add a `fail2ban` task to the playbook (package + service). Run it again. `changed=1`, then `changed=0`.
- Create a `docker` role with `ansible-galaxy init roles/docker` and move the Docker tasks into it.
- Add a Terraform output `ssh_config` that generates a `Host formini-aws` block ready for `~/.ssh/config`.
- Move the state to an S3 backend (bucket provided by the trainer): `backend "s3"` in `versions.tf`, `terraform init -migrate-state`.
- **Towards a real cluster**: [`exemples/terraform-kubespray/`](exemples/terraform-kubespray/README.en.md)
  creates three nodes in one subnet, an Internet Gateway and three Elastic IPs on AWS, with the
  Kubespray inventory generated by Terraform. The natural follow-up to part 2 to
  replace kind with a multi-node cluster.

---

## Part 2 — Formini Tasks on Kubernetes (14:00 – 15:30)

Team work, on one member's VM (the others follow over SSH or by
pair-programming). Image to deploy: the one your day 3 pipeline published, for
example `gitea.formini.local:3000/equipe-a/formini-tasks:v1.0.0`.
No image? Use `gitea.formini.local:3000/formini/formini-tasks:v1.0.0`.

### 2.1 The cluster

`k8s/kind-config.yaml`: one control plane and two workers, node port 30080
mapped to port 8080 on the VM, and containerd configured to read registries
from `/etc/containerd/certs.d`.

```bash
kind create cluster --name formini --config k8s/kind-config.yaml
kubectl cluster-info
kubectl get nodes                      # 3 nodes Ready (30 to 60 s)
docker ps                              # each node is a container
```

Allow the Gitea registry (HTTP) on each node. The `deploy.sh` script does it;
by hand:

```bash
GITEA_IP=$(getent hosts gitea.formini.local | awk '{print $1}')
for node in $(kind get nodes --name formini); do
  docker exec $node mkdir -p /etc/containerd/certs.d/gitea.formini.local:3000
  docker exec -i $node sh -c 'cat > /etc/containerd/certs.d/gitea.formini.local:3000/hosts.toml' <<EOF
server = "http://gitea.formini.local:3000"
[host."http://gitea.formini.local:3000"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF
  docker exec $node sh -c "echo '$GITEA_IP gitea.formini.local' >> /etc/hosts"
done
```

> Why `/etc/hosts`? kind nodes are containers: they do not inherit the VM's
> `/etc/hosts`.

Plan B if the pull still fails: load the image into the nodes
(`docker pull` on the VM, then `kind load docker-image <image> --name formini`).

### 2.2 Namespace and Secret

```bash
kubectl apply -f k8s/namespace.yaml
kubectl config set-context --current --namespace=formini-tasks   # no more need for -n

cp k8s/secret.example.yaml k8s/secret.yaml
nano k8s/secret.yaml                     # a real password
kubectl apply -f k8s/secret.yaml
kubectl get secret tasks-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
```

`secret.yaml` is in `.gitignore`. Check: `git status` must not list it.

### 2.3 The database

A database is not a stateless application: `k8s/postgres.yaml` declares it as a
**StatefulSet**, not a Deployment. Read the file and spot:

- the **headless** Service (`clusterIP: None`) named `postgres`: the `postgres` DNS name points
  straight at the pod, and each pod also gets a stable name, `postgres-0.postgres`;
- `serviceName`, which ties the StatefulSet to that Service;
- `volumeClaimTemplates`: one PVC **per pod**, created automatically and named `data-postgres-0`.
  Unlike a Deployment, the pod always keeps the same name and always gets the same volume back.

```bash
kubectl apply -f k8s/postgres.yaml
kubectl get statefulset,pvc     # postgres 1/1; data-postgres-0 Bound (kind's "standard" StorageClass)
kubectl get pods -w             # postgres-0 1/1 Running  (stable name, no random suffix)
kubectl logs postgres-0 | tail -5
```

> **What the StatefulSet guarantees**: `kubectl delete pod postgres-0` recreates a pod still
> called `postgres-0` that mounts the **same** volume. And `kubectl delete statefulset postgres`
> does **not** delete the PVC: the data survives, you need `kubectl delete pvc data-postgres-0`
> to wipe it on purpose.

### 2.4 The application

In `k8s/app.yaml`, replace the image with yours. Read: `replicas`,
`strategy`, `selector`/`labels`, `env` (how `DATABASE_URL` gets the password),
`readinessProbe`, `livenessProbe`, `resources`.

```bash
kubectl apply -f k8s/app.yaml
kubectl apply -f k8s/service.yaml
kubectl get pods -w                       # 2 pods tasks-xxx 1/1 Running
kubectl describe pod -l app=tasks | grep -A5 Events
curl -s localhost:8080/health             # {"status":"ok","database":"ok",...}
```

Open `http://localhost:8080` (or `http://<VM IP>:8080` from the Formini
workstation) and create two tasks.

**Persistence test**: delete the postgres pod, wait for it to come back, reload
the page: the tasks are still there.

```bash
kubectl delete pod -l app=postgres
kubectl get pods -w
```

### 2.5 Scaling

In a second terminal, leave a loop running that counts errors:

```bash
while true; do code=$(curl -s -o /dev/null -w '%{http_code}' localhost:8080/health); echo "$(date +%T) $code"; sleep 0.5; done
```

```bash
kubectl scale deploy/tasks --replicas=4
kubectl get pods -o wide                  # 4 pods, spread across the 2 workers
kubectl get endpoints tasks               # 4 addresses behind the Service
for i in $(seq 1 20); do curl -s localhost:8080/health >/dev/null; done
kubectl logs -l app=tasks --prefix | grep health | cut -d' ' -f1 | sort | uniq -c   # all 4 pods served requests
```

### 2.6 Rolling update

Have your pipeline (day 3) produce a new tag: push a commit that changes
something visible (the title in `static/index.html`, or `APP_VERSION`), and tag
it `v1.1.0`. Then:

```bash
kubectl set image deploy/tasks tasks=gitea.formini.local:3000/equipe-a/formini-tasks:v1.1.0
kubectl annotate deploy/tasks kubernetes.io/change-cause="v1.1.0 - new title" --overwrite
kubectl rollout status deploy/tasks       # follows the switch-over
kubectl rollout history deploy/tasks
kubectl get rs                            # two ReplicaSets: the old one at 0, the new one at 4
```

Watch the `curl` loop: **no code other than 200** should appear.
If you see any, check `readinessProbe` and `maxUnavailable: 0`.

### 2.7 Break it, then roll back

```bash
kubectl set image deploy/tasks tasks=gitea.formini.local:3000/equipe-a/formini-tasks:v9.9.9
kubectl get pods                          # one pod in ImagePullBackOff, the other 4 still serving
kubectl rollout status deploy/tasks --timeout=60s     # reports the failure
kubectl rollout undo deploy/tasks
kubectl rollout status deploy/tasks
kubectl rollout history deploy/tasks      # the current revision is indeed v1.1.0
```

A nastier variant: an image that starts but whose `/health` answers 503 (for
example with a broken `DATABASE_URL` via `kubectl set env deploy/tasks
DATABASE_URL=postgresql://x:x@nowhere:5432/x`). Observe that the new pods never
become `Ready` and that traffic stays on the old ones. Then
`kubectl rollout undo`.

### Success criteria

- [ ] `kubectl get all -n formini-tasks` shows: the `postgres-0` pod, N tasks pods, 2 Services, 1 Deployment, 1 StatefulSet, ReplicaSets
- [ ] A task created in the UI survives `kubectl delete pod postgres-0` (the pod comes back with the same name and the same volume)
- [ ] Zero codes ≠ 200 in the `curl` loop during the v1.0.0 → v1.1.0 update
- [ ] The `rollout undo` after the non-existent tag brings v1.1.0 back in under a minute
- [ ] `secret.yaml` absent from `git status`
- [ ] The `k8s/` folder is committed to your repository (without the secret) through a reviewed PR

### Part 2 bonus

**HPA** (autoscaling):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl apply -f k8s/hpa.yaml
kubectl get hpa -w
# generate load:
kubectl run load --rm -it --image=busybox:1.36 --restart=Never -- \
  sh -c 'while true; do wget -q -O- http://tasks.formini-tasks.svc/api/tasks >/dev/null; done'
```

**Ingress nginx**: `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml`,
then an `Ingress` object that routes `tasks.localtest.me` to the `tasks` Service
(add an `extraPortMappings` 80→80 in `kind-config.yaml` and recreate the cluster).

**Kustomize**: `k8s/base/` + `k8s/overlays/dev/` (1 replica) and
`k8s/overlays/prod/` (4 replicas, higher limits). `kubectl apply -k k8s/overlays/prod`.

---

**Complete Go + React stack on Kubernetes**: [`exemples/go-react/`](exemples/go-react/README.en.md)
deploys the Day 2 stack (React front end, Go API, PostgreSQL, Redis) in its own `formini-go`
namespace, with both databases as StatefulSets, the SQL schema as a ConfigMap and `kubectl apply -k`.
Exercises: stable pod identity, deletion without data loss, volatile Redis, rolling update.

**Shared cluster, one namespace per student**: [`exemples/namespaces-etudiants/`](exemples/namespaces-etudiants/README.en.md)
creates, for each login, a namespace, a ServiceAccount, a RoleBinding on the `admin` ClusterRole
(full rights inside, none outside), a quota and a LimitRange, then generates one kubeconfig per
student and verifies the isolation with `kubectl auth can-i`.

## Troubleshooting

| Symptom | Likely causes | Check |
|---------|---------------|-------|
| `ImagePullBackOff` / `ErrImagePull` | Wrong image name, registry not allowed over HTTP on the node, `gitea.formini.local` not resolved from the node, private image repository | `kubectl describe pod` (Events section), `docker exec formini-worker crictl pull <image>`, `docker exec formini-worker cat /etc/hosts`. Private repository: create an `imagePullSecrets` with `kubectl create secret docker-registry`. Plan B: `kind load docker-image`. |
| `CrashLoopBackOff` on tasks | Invalid `DATABASE_URL`, missing Secret, postgres not ready yet | `kubectl logs deploy/tasks --previous`, `kubectl get secret tasks-secret`, `kubectl get pods -l app=postgres` |
| tasks pod never `Ready` (0/1) | `/health` returns 503 because the database is unreachable, or the probe port is wrong | `kubectl exec deploy/tasks -- wget -qO- localhost:5000/health`, `kubectl describe pod` |
| PVC `Pending` | No default StorageClass (rare on kind), incompatible `accessModes` | `kubectl get storageclass`, `kubectl describe pvc data-postgres-0` |
| `localhost:8080` does not answer | Cluster created without `kind-config.yaml`, `nodePort` ≠ 30080, Service with no endpoints | `kubectl get svc tasks`, `kubectl get endpoints tasks`, `docker port formini-control-plane` |
| Terraform: `UnauthorizedOperation` / `AccessDenied` | Wrong or non-exported credentials, wrong region, insufficient IAM permissions | `aws sts get-caller-identity`, `env \| grep AWS` |
| Terraform: `VcpuLimitExceeded` / `InstanceLimitExceeded` | Region quota reached (the whole room is creating at the same time) | Wait a minute, retry; the trainer has requested a quota increase |
| Terraform: `InvalidKeyPair.Duplicate` | A previous apply left a key pair behind | Delete it in the EC2 console → Key pairs, or `terraform import` |
| Ansible: `UNREACHABLE` | Instance not booted yet, wrong IP, wrong key, `ansible_user` ≠ `ubuntu` | `ssh -v ubuntu@IP`, wait 60 s |
| Ansible: `Missing sudo password` | `become: true` without passwordless sudo | On AWS Ubuntu it is built in; make sure you are targeting the AWS instance |
| `terraform destroy` fails on the VPC | A resource created outside Terraform is still attached to it (ENI, manual SG) | VPC console → delete manually, rerun destroy |

Kubernetes reflex: `kubectl get pods` → `kubectl describe pod <name>` → `kubectl logs <name>`.
