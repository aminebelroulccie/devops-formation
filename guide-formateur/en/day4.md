# Trainer guide — Day 4: Infrastructure as Code and Kubernetes

_English version · la version française est dans [`../jour4.md`](../jour4.md)_

**Wednesday 11 November 2026 · 09:00 – 16:00 · Formini DevOps Training**

Material: `slides/en/day4-iac-kubernetes.html` (35 slides, presenter notes with
the `S` key) · participant lab sheet `ateliers/jour4-iac-kubernetes/README.en.md`
· solutions `ateliers/jour4-iac-kubernetes/solution/`.

Goal of the day: every participant has created and destroyed an AWS server
through code and configured it with Ansible; every team has deployed Formini
Tasks on Kubernetes, scaled it, updated it with no downtime and rolled it
back.

**Today's risk is financial**: forgotten AWS resources. Three safeguards: an
AWS Budgets alert, a mandatory destroy at 12:00 and a roll call by name at
15:30, and a console check by the trainer at 16:00.

---

## The day before (D-1, 30 minutes)

### AWS account

- [ ] IAM user `formation-devops` with the policy `setup/aws/iam-policy-formation.json` (EC2, VPC, EKS, limited IAM, S3). One key pair **per participant** (or one per team if the IAM quota is tight): create them in IAM → Users → Security credentials, record them in an encrypted file, hand them out on paper or through a private channel, never via the repository wiki.
- [ ] **AWS Budgets** alert active: threshold 50 € per month, notification at 80 % and 100 % to your e-mail. Check that the test notification arrives.
- [ ] **Quotas** in region eu-west-3: "Running On-Demand Standard instances" ≥ 2 vCPU × number of participants (t3.micro = 2 vCPU). 12 participants → 24 vCPU minimum. The default quota of a fresh account is often 5 vCPU: request the increase **one week ahead** (Service Quotas → EC2 → request increase, processed in 24 to 48 h).
- [ ] VPC quota: 5 per region by default. **One VPC per participant** exceeds this quota from 6 participants upwards: request an increase to 20, or run the Terraform lab in teams of 3. Decide the day before, not in the morning.
- [ ] Full test of `solution/terraform` from your VM: `init`, `apply`, `output`, SSH, Ansible playbook, `http://IP:5000`, `destroy`. Time it (allow 8 minutes end to end).
- [ ] EC2 console empty after the test. Saved filter in the console: tag `Project = formation-devops`.

### Trainer VM and participant VMs

- [ ] `terraform`, `ansible`, `kubectl`, `kind` installed by `setup/install-vm.sh`: check the versions on two VMs picked at random.
- [ ] `kind create cluster --name test && kind delete cluster --name test` works on a participant VM (1 minute; 4 GB of RAM is enough for 3 nodes).
- [ ] Images pre-pulled on every VM so as not to saturate the connection: `docker pull kindest/node:v1.31.0` (the installed kind version), `docker pull postgres:16-alpine`.
- [ ] Fallback image published in the Gitea registry: `gitea.formini.local:3000/formini/formini-tasks:v1.0.0` and `:v1.1.0` (different title), image repository **public**. Teams without a working pipeline will use it.
- [ ] `getent hosts gitea.formini.local` answers on the VMs (`/etc/hosts` entry added by the installation script).
- [ ] The `formation-devops` repository on Gitea contains the `ateliers/jour4-iac-kubernetes/` folder.
- [ ] Two terminals ready on the trainer VM: one for the demos, one for the `curl` loop of the rolling update.

### Room

- [ ] Projector, whiteboard (four diagrams to draw: pets vs cattle, workstation → IGW → instance, the three Deployment/ReplicaSet/Pod boxes, the rolling update timeline).
- [ ] "Destroy verified" roll-call sheet printed, one line per participant.

---

## 09:00 – 09:10 · Welcome and recap of the previous day (slides 1–3)

Open with the Day 3 pipeline: ask two teams for the tag of their latest image.
Write the available tags on the board. If a team has none, give it the fallback
image right away, without making a fuss.

Announce the financial rule, then the agenda. Sentence to say word for word:
"At 12:00 and at 15:30, I take the roll call. If your name is still without
*destroy verified*, we do not move on."

## 09:10 – 09:25 · Why IaC (slides 4–5)

Question to the room: "Who has already inherited a server that nobody knew how
it was configured?" Let two or three answers come out; they are worth more than
the slide.

Pets vs cattle on the board. Insist on "re-read": the Terraform plan in a PR is
the diff of the infrastructure. Present the three tools as layers, not as
competitors.

## 09:25 – 10:00 · Terraform (slides 6–13)

### Vocabulary and cycle (6–8)

Programming analogy: provider = library, resource = object, variable =
argument, output = return value, state = database. Say it once; it will come
back.

**Demo 1** (slide 8), on the trainer VM, projector:

```bash
cd ~/formation-devops/ateliers/jour4-iac-kubernetes/solution/terraform
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_DEFAULT_REGION=eu-west-3
cp terraform.tfvars.example terraform.tfvars && sed -i 's/formini-a1/formateur/' terraform.tfvars
terraform init
terraform plan
```

Read the plan with the room: show a `+ resource`, the `(known after apply)`
entries, the final line `9 to add`. Do not apply yet.

### First file, variables, state (9–11)

Read `main.tf` aloud, block by block. Have the participants find the dependency
chain: instance → subnet → vpc. On state (slide 11): the anecdote of the
`tfstate` committed to GitHub with RDS passwords in clear text is real and
makes an impression. S3 backend mentioned, not practised.

### The project and the commands (12–13)

Draw the path of the packet on the board following the diagram. **Demo 2**:
`terraform apply`, type `yes`, and during the two minutes of creation:

- show the EC2 console filling up (filter `Project=formation-devops`);
- remind them of the Budgets alert;
- **hand out the AWS credentials** now, one pair per person.

Then `terraform output`, and `ssh` into the instance: `hostname`, no Docker.
Leave the instance running for the Ansible demo.

Trick question to ask: "If I run `apply` again now, what happens?"
(Answer: `0 to add`, the state is up to date. That is idempotence on the
Terraform side.)

## 10:00 – 10:30 · Ansible (slides 14–18)

### Principle, inventory (14–16)

Make the explicit link with the Day 1 SSH key: "You have already done the
hardest part." **Demo 3**:

```bash
cd ../ansible
cp inventory.ini.example inventory.ini
terraform -chdir=../terraform output -raw ansible_inventory   # paste into inventory.ini
ansible web -m ping
ansible web -a "uptime"
ansible web -b -m apt -a "name=htop state=present"
ansible web -b -m apt -a "name=htop state=present"            # second time: changed=false
```

The second `apt` is the teaching moment: green instead of yellow.

### Playbook (17)

Read the solution playbook (not the simplified one on the slide), task by
task. Insist on the "why copy the code" block: the classroom registry is not
reachable from AWS, so the image is built on the spot. It is a training
compromise; say so.

**Demo 4**: `ansible-playbook playbook.yml`. Three to four minutes: meanwhile,
slide 18 (Terraform or Ansible). Then open `http://IP:5000` on the projector,
create a task, show `/health`. Run the playbook again: `changed=0`.

### Terraform or Ansible (18)

Quick grid. Question: "And to deploy the application itself, in three copies?"
Leave the question open; the answer comes at 13:00.

**Demo 5, before the break**: `terraform destroy` on the projector, `yes`, then
empty EC2 console. "This is what each of you does at 11:55."

## 10:30 – 10:45 · Break

Check that the Budgets alert has not sent anything. Prepare the roll-call
sheet.

## 10:45 – 12:00 · Guided lab, part 1 (slide 19)

Individual. Everyone creates their server, configures it, destroys it.

**Timings to announce**: 10:45 reading and variables · 10:55 `apply` · 11:05
SSH and Ansible `ping` · 11:15 playbook · 11:35 application open, bonus ·
**11:50 `destroy` for everyone** · 11:58 roll call.

Walk around. Failures in observed order of frequency:

1. Credentials not exported in the current terminal (`env | grep AWS`).
2. `owner` with an uppercase letter or an accent: the Terraform validation refuses it; read the message.
3. `public_key_path`: key generated under another name on Day 1 (`ls ~/.ssh`).
4. `VcpuLimitExceeded` when the whole room applies at the same minute: wait a minute, retry, or stagger the `apply` runs by row.
5. Ansible `UNREACHABLE`: the instance has not finished booting; wait 60 seconds.
6. Playbook: `app_src` points to a folder with no `compose.yaml` (team that did not finish Day 2): the playbook automatically falls back to `docker build` + `docker run` with SQLite, that is by design.
7. Port 5000 unreachable: security group changed by mistake, or application not listening (`docker ps` on the instance).

**11:50**: announce out loud "destroy now". **11:58**: roll call by name, each
participant says "destroy done". Tick. During lunch, check the console with the
`Project=formation-devops` filter: instances, VPCs, key pairs, volumes. Any
latecomer is dealt with at 13:00 before starting.

## 12:00 – 13:00 · Lunch

After the console check: create the kind cluster on the trainer VM and pre-pull
the images (`deploy.sh` with the fallback image), so that the 13:00 demo does
not depend on the network.

## 13:00 – 13:30 · Kubernetes (slides 20–28)

### Why, architecture, objects (21–23)

Start from the Day 2 `compose.yaml`: "perfect for developing, not enough for
operating". Three scenarios: a server goes down, traffic doubles, a new
version. The word to make them remember: **reconciliation**, continuously.

Architecture (22): do not exceed three minutes. Participants talk to the API
server with `kubectl`; the rest is internal. kind = each node is a Docker
container: `docker ps` on the projector shows it.

Objects (23): draw on the board Deployment → ReplicaSet → Pods ← Service.
"You never create a Pod by hand."

### Deployment, Service, Secret, probes (24–27)

**Demo 6**, on the prepared cluster:

```bash
kubectl get nodes
kubectl apply -f k8s/namespace.yaml && kubectl config set-context --current --namespace=formini-tasks
kubectl apply -f k8s/secret.yaml -f k8s/postgres.yaml
kubectl get pods -w          # let postgres reach Running
kubectl apply -f k8s/app.yaml -f k8s/service.yaml
kubectl get pods -w
curl -s localhost:8080/health
```

While waiting, read the YAML files on the projector. Points that lose
beginners: the three levels of metadata (slide 24), the `selector` that must
equal the template `labels`, `postgres` in the URL being a Service DNS name.
On the Secret (26): `kubectl get secret tasks-secret -o yaml` then `base64 -d`
to break the illusion of encryption.

Probes (27): "no readiness, no safe rolling update". Keep this sentence for the
next demo.

### kubectl and kind (28)

Write on the board, and leave it there all afternoon: **get pods → describe pod
→ logs**. Then `kubectl delete pod -l app=tasks` on the projector: the pods
come back on their own. That is reconciliation.

## 13:30 – 14:00 · Scaling and rolling update (slides 29–32)

**Demo 7**, two terminals side by side:

Terminal 2 (loop, stays on screen until the end):
```bash
while true; do echo "$(date +%T) $(curl -s -o /dev/null -w '%{http_code}' localhost:8080/health)"; sleep 0.5; done
```

Terminal 1:
```bash
kubectl scale deploy/tasks --replicas=4 && kubectl get pods -w
kubectl set image deploy/tasks tasks=gitea.formini.local:3000/formini/formini-tasks:v1.1.0
kubectl rollout status deploy/tasks
kubectl get rs
```

Have them notice: nothing but 200s in terminal 2. Walk through the timeline
(slide 31) while showing `get pods -w`: a v2 appears, becomes Ready, a v1
disappears.

Then the deliberate failure (32):
```bash
kubectl set image deploy/tasks tasks=gitea.formini.local:3000/formini/formini-tasks:v9.9.9
kubectl get pods                    # ImagePullBackOff on a single pod
kubectl rollout undo deploy/tasks
kubectl rollout history deploy/tasks
```

Still nothing but 200s. Close the loop with DORA: "time to restore: one
command". If time is short, skip the `/health` at 503 variant (it is in the
lab sheet).

## 14:00 – 15:30 · Self-paced challenge, part 2 (slide 33)

**Before starting**: deal with the destroy latecomers. Nobody starts Kubernetes
with a live AWS instance.

Day 1 teams. One VM per team (the one of the member whose pipeline produced the
image), the others over SSH or pairing at the keyboard.

**Timings to announce**: 14:00 cluster and registry · 14:15 database and secret
· 14:30 application reachable on 8080 · 14:45 scale and persistence test ·
15:00 rolling update v1.1.0 with curl loop · 15:15 failure and undo · 15:20 PR
of the `k8s/` folder · 15:25 one team presents.

Failures, by frequency:

1. **ImagePullBackOff**: `gitea.formini.local` not resolved from the node (the node's `/etc/hosts`, not the VM's), `hosts.toml` in the wrong place, private image repository (make the repository public in Gitea, or create an `imagePullSecrets`). Plan B that always works: `docker pull` on the VM then `kind load docker-image … --name formini`.
2. **CrashLoopBackOff** on tasks: Secret applied after the Deployment, or password different between the Secret and an already initialised postgres (delete the PVC and start again).
3. Pod never Ready: postgres not ready yet at start-up, resolves itself within 30 seconds; otherwise `kubectl exec deploy/tasks -- wget -qO- localhost:5000/health`.
4. `localhost:8080` silent: cluster created without `--config`, hence no port mapping. Recreate the cluster (one minute).
5. Codes ≠ 200 during the rolling update: `readinessProbe` missing or `maxUnavailable` left at 25 %. This is the most valuable learning moment of the afternoon; do not defuse it too quickly.
6. Team without a `v1.1.0` image: use the fallback image `formini/formini-tasks:v1.1.0`.

Visit every team at rolling-update time (around 15:00): that is when the
questions come. **15:25**: one team shows its `curl` loop and its `rollout
undo` on the projector, two minutes.

## 15:30 – 16:00 · Wrap-up (slides 34–35)

### 15:30 – 15:40 · "Destroy verified" roll call

Roll call by name with the sheet. Each participant confirms: `terraform
state list` empty, EC2 console with no instance under their first name.
Project the EC2 console filtered on `Project=formation-devops`: it must be
empty. Then VPCs, key pairs, volumes. If anything remains, delete it together
on the projector: that is a lesson too.

Ask everyone to remove the AWS credentials from their `~/.bashrc` tonight.
Revoke the IAM keys after the training (Day 5, 16:00).

### 15:40 – 15:55 · What we take away

The three cards on slide 34. Go around the table: one thing learned, one thing
still unclear. Usual unclear points: the ReplicaSet/Deployment difference
(answer: the ReplicaSet is an implementation detail of the rolling update),
what Terraform state really is (answer: the memory; without it, it recreates
everything).

### 15:55 – 16:00 · Tomorrow

- **The kind cluster stays up**: Prometheus and Grafana plug into it tomorrow morning.
- The final project starts at 11:00 tomorrow: teams will run the whole running example through it, from commit to dashboard. Teams that did not finish `k8s/` today finish it tomorrow morning.
- Reminder: AWS at zero tonight.

---

## Buffers and plan Bs

| If…                                           | Then…                                                                  |
|-----------------------------------------------|------------------------------------------------------------------------|
| The morning is 15 minutes behind              | Cut the part 1 bonuses, not the destroy. Slide 18 in one minute.       |
| AWS is unreachable (network outage, account)  | Part 1 becomes: Terraform `plan` only (works without creating anything), then Ansible against a neighbour's VM (inventory = neighbour's IP, user `devops`, Day 1 key). The playbook works as is. |
| vCPU quotas block half the room               | One apply per team; the other members read the plan and drive Ansible. |
| kind does not start on a VM (RAM, inotify)    | `sudo sysctl fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=512`, or go down to 1 worker in `kind-config.yaml`. |
| The Gitea registry refuses the kind nodes     | `kind load docker-image` for everyone, no shame: that is also what CI pipelines do with kind. |
| A team finishes at 15:00                      | HPA bonus with `metrics-server` and load generation: spectacular on the projector. |
| 10 minutes are left at 15:55                  | Show `kubectl get events --sort-by=.lastTimestamp`: the timeline of everything the cluster did during the afternoon. |

## After the day (trainer, 10 minutes)

- [ ] AWS console: instances, VPCs, key pairs, volumes, Elastic IPs, all filtered on `Project=formation-devops`, all empty.
- [ ] Cost Explorer the next morning: the day must cost less than 5 €.
- [ ] Note the unclear points from the round table for the 09:00 recap tomorrow.
- [ ] Check that the trainer VM still has its kind cluster and the application deployed: it is the target of tomorrow's Prometheus demo.
