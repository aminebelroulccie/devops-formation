# Guide formateur — Jour 2 : Conteneurisation avec Docker

**Lundi 09 novembre 2026 · 09:00 – 16:00**
Diapositives : `slides/jour2-docker.html` (touche `S` pour les notes présentateur).
Fiche participants : `ateliers/jour2-docker/README.md`. Solution : `ateliers/jour2-docker/solution/`.

## Avant 09:00 — vérifications (20 min, la veille au soir ou tôt le matin)

- [ ] Gitea répond sur <http://gitea.formini.local:3000> ; les organisations `equipe-*`
      existent et chaque participant y est membre avec droit d'écriture.
- [ ] Registre de paquets activé dans Gitea (`[packages] ENABLED = true`) : tester un
      `docker login` + `docker push` depuis votre VM.
- [ ] Sur une VM participant prise au hasard : `docker version`, `docker compose version`,
      `cat /etc/docker/daemon.json` contient `insecure-registries`.
- [ ] Images pré-tirées sur chaque VM pour économiser la bande passante :
      `nginx:1.27-alpine`, `python:3.12-slim`, `postgres:16-alpine`
      (le script `setup/install-vm.sh` le fait ; sinon `docker pull` en boucle via SSH).
- [ ] Votre dépôt de démo cloné et à jour : `~/formini-tasks` avec la solution prête dans
      un dossier à part (`~/demo-solution`), pour ne pas spoiler.
- [ ] Deux terminaux ouverts au projecteur, police agrandie ; navigateur avec Gitea.
- [ ] Un chronomètre pour la démo du cache (slide 16).

## 09:00 – 09:10 — Accueil et retour sur la veille

Reprendre les points flous notés au bilan du jour 1 (max 5 min). Annoncer l'objectif
concret du soir : *une image publiée dans le registre Gitea de chaque équipe*. Dire que
demain le pipeline reproduira tout ce qu'on fait aujourd'hui, donc on prend des notes
des commandes.

## 09:10 – 09:50 — Partie 1 : conteneurs et VM (slides 4 à 7)

**Slide 5, le problème.** Question à la salle : « Qui a déjà perdu une demi-journée à
faire tourner le projet d'un collègue ? » Laisser 2 ou 3 anecdotes. Introduire la
métaphore du conteneur maritime (on y reviendra avec le registre).

**Slide 6, VM ou conteneur.** Point central : *pas de noyau dans un conteneur*. Donner
les ordres de grandeur (secondes contre minutes, Mo contre Go). Nuancer : isolation
moins forte, et un conteneur Linux a besoin d'un noyau Linux.

**Slide 7, sous le capot — démo 1 (5 min) :**

```bash
docker run -d --name demo nginx:1.27-alpine
ps -ef | grep nginx            # visible depuis l'hôte
docker exec demo ps -ef        # PID 1 dans le conteneur
docker run --rm --memory 64m python:3.12-slim python -c "x = bytearray(200_000_000)"
# → tué par le cgroup (exit 137), bonne illustration des limites
docker rm -f demo
```

Question : « Pourquoi le processus apparaît-il des deux côtés ? » Réponse attendue :
c'est le même processus, isolé par des namespaces.

## 09:50 – 10:30 — Partie 2 : images, conteneurs, registres (slides 8 à 13)

**Slide 9, vocabulaire.** Faire répéter : *on construit une image, on lance un
conteneur, on pousse dans un registre.* Afficher `docker images` et `docker ps -a`
côte à côte.

**Slide 10, cycle de vie — démo 2 (8 min) :** dérouler exactement le bloc de la
diapositive, ouvrir `http://localhost:8080` dans le navigateur de la VM. Montrer
`docker stop` puis `docker ps -a` : « il existe encore ». Puis `docker rm`.

**Slide 11, persistance — démo 3 (6 min), celle qui marque :**

```bash
docker run -d --name db -e POSTGRES_PASSWORD=formini postgres:16-alpine
sleep 5; docker exec db psql -U postgres -c "create table t(x int); insert into t values (1);"
docker rm -f db
docker run -d --name db -e POSTGRES_PASSWORD=formini postgres:16-alpine
sleep 5; docker exec db psql -U postgres -c "select * from t;"   # → relation does not exist
docker rm -f db
# puis la même chose avec -v pgdata:/var/lib/postgresql/data : la table survit
```

**Slide 12, réseau.** Annoncer le piège numéro un de l'après-midi : `localhost` dans
`DATABASE_URL` désigne le conteneur web lui-même. Le nom du service est le nom d'hôte.

**Slide 13, Dockerfile.** Lire les six lignes ; bien distinguer `RUN` (au build) et
`CMD` (au run). Ne pas encore parler de cache ni d'utilisateur : c'est l'après-midi.

**Tampon :** si vous êtes en avance, montrer `docker inspect` sur un conteneur et
commenter trois champs (IP, mounts, config). Si en retard, sauter la démo 1.

## 10:30 – 10:45 — Pause

Pendant la pause : lancer `docker pull` des trois images sur votre VM si ce n'est pas
fait, vérifier qu'un participant au hasard a bien son clone à jour.

## 10:45 – 12:00 — Atelier guidé (slide 14)

Afficher la slide 14, puis la fiche README partie 1 sur le second écran si possible.
Rythme conseillé : 1.1 et 1.2 ensemble jusqu'à 11:10, puis chacun avance.

Passer dans les rangs. Pannes à anticiper, dans l'ordre de fréquence :

| Symptôme                                 | Fix                                                         |
|------------------------------------------|-------------------------------------------------------------|
| `permission denied` sur le socket Docker | `usermod -aG docker`, **nouvelle session** (pas juste `su`) |
| `COPY failed` / `requirements.txt not found` | `docker build` lancé hors de la racine                  |
| Port 5000 déjà pris                      | `python app.py &` de l'étape 1.2 encore vivant : `kill %1`  |
| Image de 700 Mo                          | `.venv` copié : ne rien dire, c'est l'amorce de l'après-midi |

Vers 11:45, faire un tour rapide : qui a `/health` qui répond ? Qui a vu `root` avec
`whoami` ? Qui a `.venv` dans `ls /app` ? Ces trois constats structurent la partie 3.

## 12:00 – 13:00 — Déjeuner

## 13:00 – 13:35 — Partie 3 : Dockerfiles efficaces (slides 15 à 20)

**Slide 16, cache — démo 4 chronométrée (5 min) :** avec le Dockerfile naïf du matin,
modifier un commentaire dans `app.py`, `time docker build .` (pip tourne, 30 s à 1 min).
Réordonner (requirements d'abord), rebuild : 2 s. Dire : « c'est la différence entre un
pipeline de 5 minutes et de 30 secondes demain ».

**Slide 17, .dockerignore.** Montrer la ligne `transferring context: 120MB` puis
`transferring context: 12kB` après ajout du fichier. Insister sur `.env` : un secret
dans une image est un secret public.

**Slide 18, taille.** Tableau à lire vite. Le multi-stage est un bonus pour Python,
essentiel pour Go/Java. Ne pas y passer plus de 3 minutes.

**Slide 19, le Dockerfile de référence.** Lire chaque ligne ajoutée par rapport au
matin : `ENV`, `useradd`/`USER`, `HEALTHCHECK`, `CMD` en forme exec. Question : « Que se
passe-t-il avec `CMD gunicorn ...` sans crochets ? » Réponse : un shell devient PID 1,
SIGTERM n'atteint pas gunicorn, `docker stop` attend 10 s puis tue.

**Slide 20, tags.** Anecdote des deux serveurs en `latest` avec deux versions
différentes. Le SHA de commit comme tag prépare le retour arrière Kubernetes du jour 4.

## 13:35 – 14:00 — Partie 4 : Compose et registre (slides 21 à 25)

**Slide 22, Compose.** Montrer `docker compose up -d --build` sur votre solution, puis
`docker compose ps` avec les deux `healthy`. Puis `down` (volume conservé) et `down -v`
(volume détruit) : c'est le piège du « je repars de zéro » sans vouloir perdre les données.

**Slides 23 et 24, le fichier.** Lire ligne par ligne. Faire remarquer l'absence de
`ports:` sur `db`. Montrer `docker compose config` : les variables sont résolues, mots
de passe compris, donc ne jamais coller cette sortie dans un ticket.

**Slide 25, registre — démo 5 (6 min) :** créer un jeton dans Gitea au projecteur
(Settings → Applications → portée *package* read/write), `docker login`, `tag`, `push`,
puis ouvrir l'onglet **Packages** de l'organisation. Insister sur l'anatomie du nom
complet de l'image.

## 14:00 – 15:30 — Défi en autonomie (slide 26)

Afficher la slide 26, puis laisser la slide 27 (dépannage) à l'écran pendant le défi.
Rappeler la répartition : Dockerfile / Compose / registre + PR.

Points de passage :

- **14:30** : vérifier `DATABASE_URL` de chaque équipe (le piège `localhost`) et la
  présence de `condition: service_healthy`. Une équipe sans la condition verra
  `connection refused` : les laisser chercher 5 minutes avant d'aider.
- **14:50** : `docker compose ps` doit montrer deux `healthy`. Si `db` reste
  `starting`, le mot de passe de `.env` a été changé après la création du volume :
  `down -v`.
- **15:05** : vérifier les deux tags dans Packages. Erreur fréquente : jeton sans portée
  package → `unauthorized`.
- **15:15** : une équipe montre son onglet Packages et son `compose ps` au projecteur.
  Demander : « Combien pèse votre image ? Qui est `whoami` ? »

Si une équipe termine tôt : bonus trivy (nombre de CVE critiques `slim` contre image
complète), puis multi-stage et comparaison des tailles.

**Démo optionnelle (10 min, si avance) :** `bash ateliers/jour2-docker/exemples/build-all.sh`,
lancé pendant la pause (Rust compile 2 à 5 min la première fois). Commenter le tableau des
tailles : Go distroless ≈ 8 Mo, Rust ≈ 25 Mo, React/nginx ≈ 50 Mo, Python ≈ 150 Mo. Message :
la taille dépend de ce qu'on met dans l'image finale, pas du langage. Renvoyer les participants
vers `exemples/README.md` pour le bonus « autres langages ».

## 15:30 – 16:00 — Bilan (slides 28 et 29)

Les trois points de la slide 28. Tour de table : une chose apprise, une chose encore
floue (noter pour demain). **Vérifier explicitement** que chaque équipe a une image dans
son registre : le pipeline de demain la reconstruit, mais le registre doit être
fonctionnel. Rappeler de laisser les VM allumées.

## Après la journée

- Noter les pannes rencontrées et leur fréquence pour ajuster la slide de dépannage.
- Vérifier que `act_runner` est enregistré sur la VM formateur pour demain
  (`setup/act-runner/`), et qu'un push sur un dépôt test déclenche bien un job.
- Si une équipe n'a pas réussi le push, le faire avec elle à 16:00 : le jour 3 en dépend.

## Réponses aux questions fréquentes

- *« Docker est-il sûr ? »* Moins isolant qu'une VM ; on compense avec utilisateur
  non-root, images minimales, analyse des CVE, et à terme des runtimes durcis.
- *« Pourquoi pas Podman ? »* Compatible en grande partie, sans démon, rootless par
  défaut ; Docker reste le standard de fait en formation et sur les runners.
- *« Peut-on mettre la base de données dans un conteneur en production ? »* Oui avec un
  volume et des sauvegardes, mais souvent on préfère un service managé. On en reparle
  au jour 4 avec Kubernetes.
- *« Et sur Windows ou macOS ? »* Docker Desktop lance une VM Linux légère ; les
  commandes sont identiques.
