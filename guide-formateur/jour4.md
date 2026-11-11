# Guide du formateur — Jour 4 : Infrastructure as Code et Kubernetes

**Mercredi 11 novembre 2026 · 09:00 – 16:00 · Formation DevOps Formini**

Supports : `slides/jour4-iac-kubernetes.html` (35 diapositives, notes orateur
avec la touche `S`) · fiche participant `ateliers/jour4-iac-kubernetes/README.md`
· solutions `ateliers/jour4-iac-kubernetes/solution/`.

Objectif de la journée : chaque participant a créé et détruit un serveur AWS
par le code, l'a configuré avec Ansible ; chaque équipe a déployé Formini Tasks
sur Kubernetes, l'a mis à l'échelle, mis à jour sans coupure et ramené en
arrière.

**Le risque du jour est financier** : des ressources AWS oubliées. Trois
garde-fous : alerte AWS Budgets, destroy obligatoire à 12:00 et appel
nominatif à 15:30, vérification console par le formateur à 16:00.

---

## La veille (J-1, 30 minutes)

### Compte AWS

- [ ] Utilisateur IAM `formation-devops` avec la politique `setup/aws/iam-policy-formation.json` (EC2, VPC, EKS, IAM limité, S3). Un couple de clés **par participant** (ou un par équipe si le quota IAM est serré) : les créer dans IAM → Users → Security credentials, les noter dans un fichier chiffré, les distribuer sur papier ou via un canal privé, jamais par le wiki du dépôt.
- [ ] Alerte **AWS Budgets** active : seuil 50 € mensuel, notification à 80 % et 100 % sur votre e-mail. Vérifier que la notification de test arrive.
- [ ] **Quotas** région eu-west-3 : « Running On-Demand Standard instances » ≥ 2 vCPU × nombre de participants (t3.micro = 2 vCPU). 12 participants → 24 vCPU minimum. Le quota par défaut d'un compte neuf est souvent 5 vCPU : demander la hausse **une semaine avant** (Service Quotas → EC2 → request increase, traité en 24 à 48 h).
- [ ] Quota VPC : 5 par région par défaut. **Un VPC par participant** dépasse ce quota à partir de 6 participants : demander la hausse à 20, ou faire l'atelier Terraform par équipe de 3. Décider la veille, pas le matin.
- [ ] Test complet du `solution/terraform` depuis votre VM : `init`, `apply`, `output`, SSH, playbook Ansible, `http://IP:5000`, `destroy`. Chronométrer (compter 8 minutes bout à bout).
- [ ] Console EC2 vide après le test. Filtre sauvegardé dans la console : tag `Project = formation-devops`.

### VM formateur et VM participants

- [ ] `terraform`, `ansible`, `kubectl`, `kind` installés par `setup/install-vm.sh` : vérifier les versions sur deux VM au hasard.
- [ ] `kind create cluster --name test && kind delete cluster --name test` fonctionne sur une VM participant (1 minute, 4 Go RAM suffisent pour 3 nœuds).
- [ ] Images pré-tirées sur chaque VM pour ne pas saturer la connexion : `docker pull kindest/node:v1.31.0` (la version de kind installée), `docker pull postgres:16-alpine`.
- [ ] Image de secours publiée dans le registre Gitea : `gitea.formini.local:3000/formini/formini-tasks:v1.0.0` et `:v1.1.0` (titre différent), dépôt d'images **public**. Les équipes sans pipeline fonctionnel l'utiliseront.
- [ ] `getent hosts gitea.formini.local` répond sur les VM (entrée `/etc/hosts` posée par le script d'installation).
- [ ] Le dépôt `formation-devops` sur Gitea contient le dossier `ateliers/jour4-iac-kubernetes/`.
- [ ] Deux terminaux préparés sur la VM formateur : un pour les démos, un pour la boucle `curl` du rolling update.

### Salle

- [ ] Projecteur, tableau blanc (quatre schémas à dessiner : pets vs cattle, poste → IGW → instance, les trois zones Deployment/ReplicaSet/Pod, la frise du rolling update).
- [ ] Feuille d'appel « destroy vérifié » imprimée, une ligne par participant.

---

## 09:00 – 09:10 · Accueil et retour sur la veille (slides 1–3)

Ouvrir sur le pipeline du jour 3 : demander à deux équipes le tag de leur
dernière image. Noter au tableau les tags disponibles. Si une équipe n'en a
pas, lui donner l'image de secours tout de suite, sans dramatiser.

Annoncer la règle financière, puis l'agenda. Phrase à dire telle quelle :
« À 12:00 et à 15:30, je fais l'appel. Si votre nom reste sans *destroy
vérifié*, on ne commence pas la suite. »

## 09:10 – 09:25 · Pourquoi l'IaC (slides 4–5)

Question à la salle : « Qui a déjà hérité d'un serveur dont personne ne savait
comment il était configuré ? » Laisser deux ou trois réponses, elles valent
mieux que la diapositive.

Pets vs cattle au tableau. Insister sur « relire » : le plan Terraform dans une
PR est le diff de l'infrastructure. Présenter les trois outils en couches,
pas en concurrence.

## 09:25 – 10:00 · Terraform (slides 6–13)

### Vocabulaire et cycle (6–8)

Analogie programmation : provider = bibliothèque, resource = objet, variable =
argument, output = retour, state = base de données. La dire une fois, elle
reviendra.

**Démo 1** (slide 8), sur la VM formateur, projecteur :

```bash
cd ~/formation-devops/ateliers/jour4-iac-kubernetes/solution/terraform
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_DEFAULT_REGION=eu-west-3
cp terraform.tfvars.example terraform.tfvars && sed -i 's/formini-a1/formateur/' terraform.tfvars
terraform init
terraform plan
```

Lire le plan avec la salle : montrer un `+ resource`, les `(known after apply)`,
la ligne finale `9 to add`. Ne pas appliquer encore.

### Premier fichier, variables, état (9–11)

Lire `main.tf` à voix haute, bloc par bloc. Faire trouver aux participants la
chaîne de dépendances : instance → subnet → vpc. Sur l'état (slide 11) :
l'anecdote du `tfstate` commité sur GitHub avec des mots de passe RDS en clair
est réelle et marque les esprits. Backend S3 mentionné, pas pratiqué.

### Le projet et les commandes (12–13)

Dessiner le chemin du paquet au tableau en suivant le schéma. **Démo 2** :
`terraform apply`, taper `yes`, et pendant les deux minutes de création :

- montrer la console EC2 qui se remplit (filtre `Project=formation-devops`) ;
- rappeler l'alerte Budgets ;
- **distribuer les identifiants AWS** maintenant, un couple par personne.

Puis `terraform output`, et `ssh` sur l'instance : `hostname`, pas de Docker.
Laisser l'instance tourner pour la démo Ansible.

Question piège à poser : « Si je relance `apply` maintenant, que se passe-t-il ? »
(Réponse : `0 to add`, l'état est à jour. C'est l'idempotence côté Terraform.)

## 10:00 – 10:30 · Ansible (slides 14–18)

### Principe, inventaire (14–16)

Faire le lien explicite avec la clé SSH du jour 1 : « Vous avez déjà fait le
plus dur. » **Démo 3** :

```bash
cd ../ansible
cp inventory.ini.example inventory.ini
terraform -chdir=../terraform output -raw ansible_inventory   # coller dans inventory.ini
ansible web -m ping
ansible web -a "uptime"
ansible web -b -m apt -a "name=htop state=present"
ansible web -b -m apt -a "name=htop state=present"            # deuxième fois : changed=false
```

Le second `apt` est le moment pédagogique : vert au lieu de jaune.

### Playbook (17)

Lire le playbook de la solution (pas celui simplifié de la slide), tâche par
tâche. Insister sur le bloc « pourquoi copier le code » : le registre de la
salle n'est pas joignable depuis AWS, donc on construit l'image sur place.
C'est un compromis de formation, le dire.

**Démo 4** : `ansible-playbook playbook.yml`. Trois à quatre minutes :
pendant ce temps, slide 18 (Terraform ou Ansible). Puis ouvrir `http://IP:5000`
au projecteur, créer une tâche, montrer `/health`. Relancer le playbook :
`changed=0`.

### Terraform ou Ansible (18)

Grille rapide. Question : « Et pour déployer l'application elle-même, en trois
exemplaires ? » Laisser la question ouverte, réponse à 13:00.

**Démo 5, avant la pause** : `terraform destroy` au projecteur, `yes`, puis
console EC2 vide. « Voilà ce que chacun fait à 11:55. »

## 10:30 – 10:45 · Pause

Vérifier que l'alerte Budgets n'a rien envoyé. Préparer la feuille d'appel.

## 10:45 – 12:00 · Atelier guidé, partie 1 (slide 19)

Individuel. Chacun crée son serveur, le configure, le détruit.

**Minutage à annoncer** : 10:45 lecture et variables · 10:55 `apply` · 11:05
SSH et `ping` Ansible · 11:15 playbook · 11:35 application ouverte, bonus ·
**11:50 `destroy` pour tout le monde** · 11:58 appel.

Circuler. Pannes dans l'ordre de fréquence observée :

1. Identifiants non exportés dans le terminal courant (`env | grep AWS`).
2. `owner` avec majuscule ou accent : la validation Terraform refuse, lire le message.
3. `public_key_path` : clé générée sous un autre nom au jour 1 (`ls ~/.ssh`).
4. `VcpuLimitExceeded` quand toute la salle applique à la même minute : attendre une minute, relancer, ou étaler les `apply` par rangée.
5. Ansible `UNREACHABLE` : l'instance n'a pas fini de démarrer ; attendre 60 secondes.
6. Playbook : `app_src` pointe vers un dossier sans `compose.yaml` (équipe qui n'a pas fini le jour 2) : le playbook bascule automatiquement sur `docker build` + `docker run` avec SQLite, c'est prévu.
7. Port 5000 injoignable : groupe de sécurité modifié par erreur, ou application qui n'écoute pas (`docker ps` sur l'instance).

**11:50** : annoncer à voix haute « destroy maintenant ». **11:58** : appel
nominatif, chaque participant dit « destroy terminé ». Cocher. Pendant le
déjeuner, vérifier la console avec le filtre `Project=formation-devops` :
instances, VPC, key pairs, volumes. Tout retardataire est traité à 13:00
avant de commencer.

## 12:00 – 13:00 · Déjeuner

Après vérification console : créer le cluster kind sur la VM formateur et
pré-tirer les images (`deploy.sh` avec l'image de secours), pour que la démo
de 13:00 ne dépende pas du réseau.

## 13:00 – 13:30 · Kubernetes (slides 20–29)

### Pourquoi, architecture, objets (21–23)

Partir du `compose.yaml` du jour 2 : « parfait pour développer, insuffisant
pour exploiter ». Trois scénarios : un serveur tombe, le trafic double, une
nouvelle version. Le mot à faire retenir : **réconciliation**, en continu.

Architecture (22) : ne pas dépasser trois minutes. Les participants parlent à
l'API server avec `kubectl`, le reste est interne. kind = chaque nœud est un
conteneur Docker : `docker ps` au projecteur le montre.

Objets (23) : dessiner au tableau Deployment → ReplicaSet → Pods ← Service.
« On ne crée jamais un Pod à la main. »

### Deployment, Service, Secret, probes (24–28)

**Démo 6**, sur le cluster préparé :

```bash
kubectl get nodes
kubectl apply -f k8s/namespace.yaml && kubectl config set-context --current --namespace=formini-tasks
kubectl apply -f k8s/secret.yaml -f k8s/postgres.yaml
kubectl get pods -w          # laisser postgres-0 passer Running (StatefulSet : nom stable, PVC data-postgres-0)
kubectl apply -f k8s/app.yaml -f k8s/service.yaml
kubectl get pods -w
curl -s localhost:8080/health
```

Pendant les attentes, lire les YAML au projecteur. Points qui perdent les
débutants : les trois niveaux de métadonnées (slide 24), le `selector` qui doit
égaler les `labels` du template, `postgres` dans l'URL qui est un nom DNS de
Service. Sur le Secret (27) : `kubectl get secret tasks-secret -o yaml` puis
`base64 -d` pour casser l'illusion de chiffrement.

Probes (28) : « sans readiness, pas de rolling update sûr ». Garder cette
phrase pour la démo suivante.

### kubectl et kind (29)

Écrire au tableau, et laisser toute l'après-midi : **get pods → describe pod →
logs**. Puis `kubectl delete pod -l app=tasks` au projecteur : les pods
reviennent seuls. C'est la réconciliation.

## 13:30 – 14:00 · Échelle et rolling update (slides 30–33)

**Démo 7**, deux terminaux côte à côte :

Terminal 2 (boucle, reste affiché jusqu'à la fin) :
```bash
while true; do echo "$(date +%T) $(curl -s -o /dev/null -w '%{http_code}' localhost:8080/health)"; sleep 0.5; done
```

Terminal 1 :
```bash
kubectl scale deploy/tasks --replicas=4 && kubectl get pods -w
kubectl set image deploy/tasks tasks=gitea.formini.local:3000/formini/formini-tasks:v1.1.0
kubectl rollout status deploy/tasks
kubectl get rs
```

Faire constater : que des 200 dans le terminal 2. Dérouler la frise (slide 32)
en montrant `get pods -w` : un v2 apparaît, passe Ready, un v1 disparaît.

Puis la panne volontaire (33) :
```bash
kubectl set image deploy/tasks tasks=gitea.formini.local:3000/formini/formini-tasks:v9.9.9
kubectl get pods                    # ImagePullBackOff sur un seul pod
kubectl rollout undo deploy/tasks
kubectl rollout history deploy/tasks
```

Toujours que des 200. Boucler sur DORA : « temps de rétablissement : une
commande ». Si le temps manque, sauter la variante `/health` à 503 (elle est
dans la fiche).

## 14:00 – 15:30 · Défi en équipe, partie 2 (slide 34)

**Avant de lancer** : traiter les retardataires du destroy. Personne ne
commence Kubernetes avec une instance AWS vivante.

Équipes du jour 1. Une VM par équipe (celle du membre dont le pipeline a
produit l'image), les autres en SSH ou en binôme au clavier.

**Minutage à annoncer** : 14:00 cluster et registre · 14:15 base et secret ·
14:30 application joignable sur 8080 · 14:45 scale et test de persistance ·
15:00 rolling update v1.1.0 avec boucle curl · 15:15 panne et undo · 15:20 PR
du dossier `k8s/` · 15:25 une équipe présente.

Pannes, par fréquence :

1. **ImagePullBackOff** : `gitea.formini.local` non résolu depuis le nœud (le `/etc/hosts` du nœud, pas celui de la VM), `hosts.toml` mal placé, dépôt d'images privé (pousser le dépôt en public dans Gitea, ou créer un `imagePullSecrets`). Plan B qui marche toujours : `docker pull` sur la VM puis `kind load docker-image … --name formini`.
2. **CrashLoopBackOff** sur tasks : Secret appliqué après le Deployment, ou mot de passe différent entre le Secret et un postgres déjà initialisé (supprimer le PVC `data-postgres-0` et recommencer : le StatefulSet ne le supprime jamais seul).
3. Pod jamais Ready : postgres pas encore prêt au démarrage, se résout seul en 30 secondes ; sinon `kubectl exec deploy/tasks -- wget -qO- localhost:5000/health`.
4. `localhost:8080` muet : cluster créé sans `--config`, donc pas de mapping de port. Recréer le cluster (une minute).
5. Codes ≠ 200 pendant le rolling update : `readinessProbe` absente ou `maxUnavailable` laissé à 25 %. C'est le moment d'apprentissage le plus précieux de l'après-midi, ne pas le déminer trop vite.
6. Équipe sans image `v1.1.0` : utiliser l'image de secours `formini/formini-tasks:v1.1.0`.

Passer voir chaque équipe au moment du rolling update (vers 15:00) : c'est là
que les questions arrivent. **15:25** : une équipe montre sa boucle `curl` et
son `rollout undo` au projecteur, deux minutes.

**Équipes en avance, ou qui ont suivi la pile Go + React des jours 2 et 3 :**
`ateliers/jour4-iac-kubernetes/exemples/go-react/` (namespace `formini-go`, port 30081 → 8081 si
le cluster a été créé avec son `kind-config.yaml`, sinon `port-forward`). Bon support pour la
question « Deployment ou StatefulSet ? » : quatre objets, deux de chaque.

**Pour aller plus loin après la formation (ne pas lancer en séance, 3 machines payantes et 20 min
de Kubespray) :** `ateliers/jour4-iac-kubernetes/exemples/terraform-kubespray/` — trois nœuds AWS,
un sous-réseau, une Internet Gateway, trois Elastic IP, inventaire Kubespray généré. À mentionner au bilan
comme réponse à « et sans kind, comment on fait ? ». Sur ce cluster partagé,
`exemples/namespaces-etudiants/` donne à chacun des six un namespace et un kubeconfig limité à
celui-ci (`generate.sh --apply`, `make-kubeconfigs.sh`, `verify.sh`) : préparer avant la séance,
distribuer les fichiers un par un.

## 15:30 – 16:00 · Bilan (slides 35–36)

### 15:30 – 15:40 · Appel « destroy vérifié »

Appel nominatif avec la feuille. Chaque participant confirme : `terraform
state list` vide, console EC2 sans instance à son prénom. Projeter la console
EC2 filtrée `Project=formation-devops` : elle doit être vide. Puis VPC, key
pairs, volumes. Si quelque chose reste, le supprimer ensemble au projecteur :
c'est aussi une leçon.

Demander à chacun de retirer les identifiants AWS de son `~/.bashrc` ce soir.
Révoquer les clés IAM après la formation (jour 5, 16:00).

### 15:40 – 15:55 · Ce que l'on retient

Les trois cartes de la slide 35. Tour de table : une chose apprise, une chose
floue. Points flous habituels : la différence ReplicaSet/Deployment (répondre :
le ReplicaSet est un détail d'implémentation du rolling update), ce qu'est
vraiment le state Terraform (répondre : la mémoire, sans elle il recrée tout).

### 15:55 – 16:00 · Demain

- **Le cluster kind reste allumé** : Prometheus et Grafana s'y branchent demain matin.
- Le projet final commence à 11:00 demain : les équipes y feront passer tout le fil rouge, du commit au tableau de bord. Les équipes qui n'ont pas fini le `k8s/` aujourd'hui le finissent demain matin.
- Rappel : AWS à zéro ce soir.

---

## Marges et plans B

| Si…                                           | Alors…                                                                 |
|-----------------------------------------------|------------------------------------------------------------------------|
| La matinée a 15 minutes de retard             | Couper les bonus de la partie 1, pas le destroy. Slide 18 en une minute. |
| AWS est inaccessible (panne réseau, compte)   | Partie 1 devient : Terraform `plan` seul (fonctionne sans créer), puis Ansible contre la VM d'un voisin (inventaire = IP du voisin, user `devops`, clé du jour 1). Le playbook marche tel quel. |
| Les quotas vCPU bloquent la moitié de la salle | Un apply par équipe, les autres membres lisent le plan et pilotent Ansible. |
| kind ne démarre pas sur une VM (RAM, inotify) | `sudo sysctl fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=512`, ou passer à 1 worker dans `kind-config.yaml`. |
| Le registre Gitea refuse les nœuds kind      | `kind load docker-image` pour tout le monde, sans honte : c'est aussi ce que font les pipelines CI avec kind. |
| Une équipe finit à 15:00                      | Bonus HPA avec `metrics-server` et génération de charge : spectaculaire au projecteur. |
| Il reste 10 minutes à 15:55                   | Montrer `kubectl get events --sort-by=.lastTimestamp` : la timeline de tout ce que le cluster a fait dans l'après-midi. |

## Après la journée (formateur, 10 minutes)

- [ ] Console AWS : instances, VPC, key pairs, volumes, Elastic IP, tous filtrés par `Project=formation-devops`, tout vide.
- [ ] Cost Explorer le lendemain matin : la journée doit coûter moins de 5 €.
- [ ] Noter les points flous du tour de table pour la reprise de 09:00 demain.
- [ ] Vérifier que la VM formateur a bien son cluster kind et l'application déployée : c'est la cible de la démo Prometheus de demain.
