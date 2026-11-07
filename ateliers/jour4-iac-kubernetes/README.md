# Jour 4 — Atelier : Infrastructure as Code et Kubernetes

**Mercredi 11 novembre 2026 · Formation DevOps Formini**

| Partie | Horaire       | Format      | Contenu                                                     |
|--------|---------------|-------------|-------------------------------------------------------------|
| 1      | 10:45 – 12:00 | Individuel  | Terraform crée un serveur AWS, Ansible y déploie l'application |
| 2      | 14:00 – 15:30 | Par équipe  | Formini Tasks sur Kubernetes (kind) : déployer, mettre à l'échelle, mettre à jour, revenir en arrière |

Les fichiers de solution sont dans [`solution/`](solution/). Essayez d'abord
sans, consultez-les quand vous êtes bloqué plus de dix minutes.

> **Règle absolue du jour** : tout ce qui est créé sur AWS est détruit avec
> `terraform destroy` **avant 12:00** (fin de la partie 1) et vérifié dans la
> console. Le formateur fait l'appel à 15:30.

---

## Objectifs

À la fin de l'atelier, vous savez :

- écrire et lire un projet Terraform (providers, resources, variables, outputs, state) ;
- dérouler `init → plan → apply → destroy` sur AWS en lisant le plan ;
- configurer un serveur avec un playbook Ansible idempotent, sans jamais vous y connecter à la main ;
- déployer une application et sa base sur Kubernetes avec Deployment, Service, Secret, PVC ;
- mettre à l'échelle, faire une mise à jour progressive sans coupure, et revenir en arrière.

## Prérequis

Sur votre VM Formini (Ubuntu 24.04, utilisateur `devops`) :

```bash
terraform version     # >= 1.6
ansible --version     # >= 2.14
kubectl version --client
kind version          # >= 0.20
docker ps             # Docker fonctionne sans sudo
ls ~/.ssh/id_ed25519.pub   # la clé du jour 1
```

Identifiants AWS fournis par le formateur (un couple par participant) :

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="eu-west-3"     # Paris
```

Ajoutez ces trois lignes à `~/.bashrc` pour la journée, et **supprimez-les ce soir**.
Ne les mettez jamais dans un fichier du dépôt.

Récupérez le matériel de l'atelier dans votre clone du dépôt de formation :

```bash
cd ~/formation-devops/ateliers/jour4-iac-kubernetes
cp -r solution/terraform solution/ansible solution/k8s ~/formini-tasks/   # dans votre dépôt applicatif
```

(Vous pouvez aussi écrire chaque fichier vous-même en suivant les slides : c'est le but.)

---

## Partie 1 — Un serveur AWS, de zéro à l'application (10:45 – 12:00)

### 1.1 Lire le projet Terraform

Dans `terraform/`, cinq fichiers :

| Fichier                   | Rôle                                                           |
|---------------------------|----------------------------------------------------------------|
| `versions.tf`             | Version de Terraform, provider AWS `~> 5.0`, tags par défaut   |
| `variables.tf`            | Région, prénom, type d'instance, chemin de la clé publique     |
| `main.tf`                 | VPC, sous-réseau public, IGW, table de routage, SG, key pair, AMI Ubuntu 24.04, instance |
| `outputs.tf`              | IP publique, commande SSH, ligne d'inventaire Ansible          |
| `user_data.sh`            | Script de premier démarrage (nom d'hôte, python3)              |

Avant de taper une commande, répondez par écrit :

1. Combien de ressources `resource` ? Combien de `data` ?
2. Dans quel ordre Terraform va-t-il les créer, et pourquoi ?
3. Quels ports sont ouverts depuis Internet ?

### 1.2 Préparer les variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars          # owner = "votre-prenom"  (minuscules, sans accent)
```

Bonus sécurité : remplacez `ssh_allowed_cidr` par votre IP publique en `/32`
(`curl -s ifconfig.me`).

### 1.3 init, plan, apply

```bash
terraform init          # télécharge le provider AWS, crée .terraform.lock.hcl
terraform fmt           # met en forme
terraform validate      # vérifie syntaxe et références
terraform plan          # LIRE : "Plan: 9 to add, 0 to change, 0 to destroy."
terraform apply         # relire le plan, taper yes
```

Comptez : la création prend deux à trois minutes. Pendant ce temps, ouvrez la
console AWS (région Paris) → EC2 → Instances, filtrez par tag `Owner`.

```bash
terraform output                      # public_ip, ssh, app_url, ansible_inventory
terraform state list                  # les 9 objets connus
terraform state show aws_instance.web # tout ce qu'AWS a renvoyé
```

### 1.4 Se connecter en SSH

```bash
$(terraform output -raw ssh)          # exécute la commande ssh de l'output
# ou
ssh -i ~/.ssh/id_ed25519 ubuntu@$(terraform output -raw public_ip)
```

Sur le serveur : `hostname`, `cat /var/log/formini-user-data.log`, `docker`
(absent : c'est le travail d'Ansible). Déconnectez-vous.

> Si la connexion est refusée dans la première minute, l'instance démarre
> encore. Si elle reste refusée : `terraform state show aws_security_group.web`,
> vérifiez le port 22 et `ssh_allowed_cidr`.

### 1.5 Ansible : inventaire et ping

```bash
cd ../ansible
cp inventory.ini.example inventory.ini
terraform -chdir=../terraform output -raw ansible_inventory   # copier cette ligne dans inventory.ini
ansible web -m ping
ansible web -a "uptime"
ansible web -b -m apt -a "name=htop state=present"           # un module, ad hoc, avec sudo
```

### 1.6 Le playbook

Lisez `playbook.yml` en entier. Repérez : `hosts`, `become`, les modules
utilisés, le `notify`/`handlers`, les `tags`, et **comment l'application
arrive sur le serveur**.

> **Pourquoi copier le code plutôt que tirer l'image du registre Gitea ?**
> Le registre `gitea.formini.local:3000` est sur le réseau de la salle, en HTTP :
> le serveur AWS ne peut pas le joindre. Le playbook copie donc le dépôt
> applicatif (avec le `Dockerfile` et le `compose.yaml` du jour 2) et construit
> l'image **sur le serveur**. En production, on tirerait l'image depuis un
> registre accessible (ECR, Docker Hub, Gitea exposé en HTTPS).

Le playbook cherche le code dans `app_src` (par défaut le dossier
`app/formini-tasks` du dépôt de formation). Pour pointer vers **votre** dépôt :

```bash
ansible-playbook playbook.yml -e app_src=$HOME/formini-tasks
```

Déroulez :

```bash
ansible-playbook playbook.yml --check        # simulation : rien n'est modifié
ansible-playbook playbook.yml                # pour de vrai (3 à 4 minutes)
ansible-playbook playbook.yml                # une deuxième fois : changed=0 ?
```

Ouvrez `http://<IP>:5000` depuis le poste Formini, créez une tâche. Vérifiez
`/health` et `/metrics`.

### 1.7 Détruire, vérifier

```bash
cd ../terraform
terraform destroy          # "Plan: 0 to add, 0 to change, 9 to destroy." → yes
terraform state list       # vide
```

**Checklist de fin de partie 1** (cochez réellement) :

- [ ] `terraform destroy` terminé sans erreur (`Destroy complete! Resources: 9 destroyed.`)
- [ ] Console EC2 → Instances : aucune instance `formini-<prénom>-web` (même « terminated » disparaît en une heure)
- [ ] Console VPC : aucun VPC `formini-<prénom>-vpc`
- [ ] Console EC2 → Key pairs : aucune `formini-<prénom>`
- [ ] Console EC2 → Volumes : aucun volume orphelin
- [ ] `aws ec2 describe-instances --filters Name=tag:Owner,Values=<prénom>` ne renvoie rien (si la CLI est installée)

### Bonus partie 1

- Ajoutez une tâche `fail2ban` au playbook (paquet + service). Rejouez. `changed=1` puis `changed=0`.
- Créez un rôle `docker` avec `ansible-galaxy init roles/docker` et déplacez-y les tâches Docker.
- Ajoutez un output Terraform `ssh_config` qui génère un bloc `Host formini-aws` prêt pour `~/.ssh/config`.
- Passez l'état en backend S3 (bucket fourni par le formateur) : `backend "s3"` dans `versions.tf`, `terraform init -migrate-state`.

---

## Partie 2 — Formini Tasks sur Kubernetes (14:00 – 15:30)

Travail par équipe, sur la VM d'un membre (les autres suivent en SSH ou en
pair-programming). Image à déployer : celle que votre pipeline du jour 3 a
publiée, par exemple `gitea.formini.local:3000/equipe-a/formini-tasks:v1.0.0`.
Pas d'image ? Utilisez `gitea.formini.local:3000/formini/formini-tasks:v1.0.0`.

### 2.1 Le cluster

`k8s/kind-config.yaml` : un control plane et deux workers, le port 30080 du
nœud mappé sur le port 8080 de la VM, et containerd configuré pour lire les
registres dans `/etc/containerd/certs.d`.

```bash
kind create cluster --name formini --config k8s/kind-config.yaml
kubectl cluster-info
kubectl get nodes                      # 3 nœuds Ready (30 à 60 s)
docker ps                              # chaque nœud est un conteneur
```

Autorisez le registre Gitea (HTTP) sur chaque nœud. Le script `deploy.sh` le
fait ; à la main :

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

> Pourquoi `/etc/hosts` ? Les nœuds kind sont des conteneurs : ils n'héritent
> pas du `/etc/hosts` de la VM.

Plan B si le pull échoue toujours : charger l'image dans les nœuds
(`docker pull` sur la VM, puis `kind load docker-image <image> --name formini`).

### 2.2 Namespace et Secret

```bash
kubectl apply -f k8s/namespace.yaml
kubectl config set-context --current --namespace=formini-tasks   # plus besoin de -n

cp k8s/secret.example.yaml k8s/secret.yaml
nano k8s/secret.yaml                     # un vrai mot de passe
kubectl apply -f k8s/secret.yaml
kubectl get secret tasks-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
```

`secret.yaml` est dans `.gitignore`. Vérifiez : `git status` ne doit pas le lister.

### 2.3 La base de données

`k8s/postgres.yaml` contient un PVC de 1 Gi, un Deployment (1 réplique,
stratégie `Recreate`), un Service ClusterIP nommé `postgres`.

```bash
kubectl apply -f k8s/postgres.yaml
kubectl get pvc                 # Bound (kind a une StorageClass "standard" par défaut)
kubectl get pods -w             # postgres-xxx 1/1 Running
kubectl logs deploy/postgres | tail -5
```

### 2.4 L'application

Dans `k8s/app.yaml`, remplacez l'image par la vôtre. Lisez : `replicas`,
`strategy`, `selector`/`labels`, `env` (comment `DATABASE_URL` récupère le mot
de passe), `readinessProbe`, `livenessProbe`, `resources`.

```bash
kubectl apply -f k8s/app.yaml
kubectl apply -f k8s/service.yaml
kubectl get pods -w                       # 2 pods tasks-xxx 1/1 Running
kubectl describe pod -l app=tasks | grep -A5 Events
curl -s localhost:8080/health             # {"status":"ok","database":"ok",...}
```

Ouvrez `http://localhost:8080` (ou `http://<IP de la VM>:8080` depuis le
poste Formini), créez deux tâches.

**Test de persistance** : supprimez le pod postgres, attendez qu'il revienne,
rechargez la page : les tâches sont toujours là.

```bash
kubectl delete pod -l app=postgres
kubectl get pods -w
```

### 2.5 Mise à l'échelle

Dans un second terminal, laissez tourner une boucle qui compte les erreurs :

```bash
while true; do code=$(curl -s -o /dev/null -w '%{http_code}' localhost:8080/health); echo "$(date +%T) $code"; sleep 0.5; done
```

```bash
kubectl scale deploy/tasks --replicas=4
kubectl get pods -o wide                  # 4 pods, répartis sur les 2 workers
kubectl get endpoints tasks               # 4 adresses derrière le Service
for i in $(seq 1 20); do curl -s localhost:8080/health >/dev/null; done
kubectl logs -l app=tasks --prefix | grep health | cut -d' ' -f1 | sort | uniq -c   # les 4 pods ont servi
```

### 2.6 Mise à jour progressive

Faites produire un nouveau tag par votre pipeline (jour 3) : poussez un commit
qui change quelque chose de visible (le titre dans `static/index.html`, ou
`APP_VERSION`), taguez `v1.1.0`. Puis :

```bash
kubectl set image deploy/tasks tasks=gitea.formini.local:3000/equipe-a/formini-tasks:v1.1.0
kubectl annotate deploy/tasks kubernetes.io/change-cause="v1.1.0 - nouveau titre" --overwrite
kubectl rollout status deploy/tasks       # suit la bascule
kubectl rollout history deploy/tasks
kubectl get rs                            # deux ReplicaSets : l'ancien à 0, le nouveau à 4
```

Regardez la boucle `curl` : **aucun code différent de 200** ne doit apparaître.
Si vous en voyez, vérifiez `readinessProbe` et `maxUnavailable: 0`.

### 2.7 Casser, puis revenir en arrière

```bash
kubectl set image deploy/tasks tasks=gitea.formini.local:3000/equipe-a/formini-tasks:v9.9.9
kubectl get pods                          # un pod ImagePullBackOff, les 4 autres servent toujours
kubectl rollout status deploy/tasks --timeout=60s     # échec annoncé
kubectl rollout undo deploy/tasks
kubectl rollout status deploy/tasks
kubectl rollout history deploy/tasks      # la révision courante est bien v1.1.0
```

Variante plus vicieuse : une image qui démarre mais dont `/health` répond 503
(par exemple avec `DATABASE_URL` cassée via `kubectl set env deploy/tasks
DATABASE_URL=postgresql://x:x@nulle-part:5432/x`). Observez que les nouveaux
pods ne passent jamais `Ready` et que le trafic reste sur les anciens. Puis
`kubectl rollout undo`.

### Critères de réussite

- [ ] `kubectl get all -n formini-tasks` montre : 1 postgres, N tasks, 2 Services, 2 Deployments, ReplicaSets
- [ ] Une tâche créée dans l'interface survit à `kubectl delete pod -l app=postgres`
- [ ] Zéro code ≠ 200 dans la boucle `curl` pendant la mise à jour v1.0.0 → v1.1.0
- [ ] Le `rollout undo` après le tag inexistant ramène v1.1.0 en moins d'une minute
- [ ] `secret.yaml` absent de `git status`
- [ ] Le dossier `k8s/` est commité dans votre dépôt (sans le secret) via une PR relue

### Bonus partie 2

**HPA** (mise à l'échelle automatique) :

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl apply -f k8s/hpa.yaml
kubectl get hpa -w
# générer de la charge :
kubectl run load --rm -it --image=busybox:1.36 --restart=Never -- \
  sh -c 'while true; do wget -q -O- http://tasks.formini-tasks.svc/api/tasks >/dev/null; done'
```

**Ingress nginx** : `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml`,
puis un objet `Ingress` qui route `tasks.localtest.me` vers le Service `tasks`
(ajoutez un `extraPortMappings` 80→80 dans `kind-config.yaml` et recréez le cluster).

**Kustomize** : `k8s/base/` + `k8s/overlays/dev/` (1 réplique) et
`k8s/overlays/prod/` (4 répliques, limites plus hautes). `kubectl apply -k k8s/overlays/prod`.

---

## Dépannage

| Symptôme | Causes probables | Vérifier |
|----------|------------------|----------|
| `ImagePullBackOff` / `ErrImagePull` | Nom d'image faux, registre non autorisé en HTTP sur le nœud, `gitea.formini.local` non résolu depuis le nœud, dépôt d'images privé | `kubectl describe pod` (section Events), `docker exec formini-worker crictl pull <image>`, `docker exec formini-worker cat /etc/hosts`. Dépôt privé : créer un `imagePullSecrets` avec `kubectl create secret docker-registry`. Plan B : `kind load docker-image`. |
| `CrashLoopBackOff` sur tasks | `DATABASE_URL` invalide, Secret absent, postgres pas encore prêt | `kubectl logs deploy/tasks --previous`, `kubectl get secret tasks-secret`, `kubectl get pods -l app=postgres` |
| Pod tasks jamais `Ready` (0/1) | `/health` renvoie 503 car la base est injoignable, ou le port de la probe est faux | `kubectl exec deploy/tasks -- wget -qO- localhost:5000/health`, `kubectl describe pod` |
| PVC `Pending` | Pas de StorageClass par défaut (rare sur kind), `accessModes` incompatible | `kubectl get storageclass`, `kubectl describe pvc postgres-data` |
| `localhost:8080` ne répond pas | Cluster créé sans `kind-config.yaml`, `nodePort` ≠ 30080, Service sans endpoints | `kubectl get svc tasks`, `kubectl get endpoints tasks`, `docker port formini-control-plane` |
| Terraform : `UnauthorizedOperation` / `AccessDenied` | Identifiants faux ou non exportés, mauvaise région, droits IAM insuffisants | `aws sts get-caller-identity`, `env \| grep AWS` |
| Terraform : `VcpuLimitExceeded` / `InstanceLimitExceeded` | Quota de la région atteint (toute la salle crée en même temps) | Attendre une minute, réessayer ; le formateur a demandé une hausse de quota |
| Terraform : `InvalidKeyPair.Duplicate` | Un apply précédent a laissé une key pair | Supprimer dans la console EC2 → Key pairs, ou `terraform import` |
| Ansible : `UNREACHABLE` | Instance pas encore démarrée, mauvaise IP, mauvaise clé, `ansible_user` ≠ `ubuntu` | `ssh -v ubuntu@IP`, attendre 60 s |
| Ansible : `Missing sudo password` | `become: true` sans sudo sans mot de passe | Sur Ubuntu AWS c'est natif ; vérifiez que vous ciblez bien l'instance AWS |
| `terraform destroy` échoue sur le VPC | Une ressource créée hors Terraform s'y accroche (ENI, SG manuel) | Console VPC → supprimer manuellement, relancer destroy |

Réflexe Kubernetes : `kubectl get pods` → `kubectl describe pod <nom>` → `kubectl logs <nom>`.
