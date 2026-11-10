# Jour 2 — Atelier : Conteneurisation avec Docker

**Objectif de la journée :** faire tourner Formini Tasks et sa base PostgreSQL dans des
conteneurs, puis publier l'image dans le registre de conteneurs Gitea de votre équipe.

| Partie | Créneau       | Mode        | Résultat attendu                                      |
|--------|---------------|-------------|-------------------------------------------------------|
| 1      | 10:45 – 12:00 | Guidé       | Un `Dockerfile` qui construit et lance l'application  |
| 2      | 14:00 – 15:30 | En autonomie| `compose.yaml` web + db, image publiée dans Gitea     |

## Prérequis

- Votre VM Ubuntu 24.04 accessible en SSH (atelier du jour 1).
- Docker installé par `setup/install-vm.sh`. Vérifiez :

```bash
docker version          # Client et Server doivent répondre
docker compose version
id | grep docker        # votre utilisateur est dans le groupe docker
```

  Si `docker` répond `permission denied` : `sudo usermod -aG docker $USER`, puis
  ouvrez une **nouvelle** session SSH.
- Votre clone du dépôt de l'équipe, à jour :

```bash
cd ~/formini-tasks && git switch main && git pull
```

- Gitea : <http://gitea.formini.local:3000>, organisation `equipe-a` (remplacez par la vôtre).

---

## Partie 1 — Atelier guidé : premier conteneur, premier Dockerfile

### 1.1 Premiers pas avec un conteneur

```bash
docker run -d --name web -p 8080:80 nginx:1.27-alpine
docker ps
```

Sortie attendue (une ligne avec `web`, état `Up`, ports `0.0.0.0:8080->80/tcp`).

```bash
curl -s localhost:8080 | head -5        # la page d'accueil nginx
docker logs web                          # les lignes de journal de la requête curl
docker exec -it web sh                   # un shell dans le conteneur
  # dans le conteneur :
  ps -ef                                 # nginx est PID 1
  cat /etc/nginx/conf.d/default.conf
  exit
docker stop web
docker ps -a                             # le conteneur existe encore, état Exited
docker rm web
docker ps -a                             # plus rien
```

Questions à vous poser : quelle est la différence entre `docker stop` et `docker rm` ?
Pourquoi `ps -ef` sur la VM montre-t-il aussi le processus nginx ?

### 1.2 Lancer l'application sans Docker (pour comparer)

```bash
cd ~/formini-tasks
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q                                # 7 tests passent
python app.py &                          # http://<ip-vm>:5000
curl -s localhost:5000/health
kill %1 ; deactivate
```

Tout ce que vous venez de faire à la main (installer Python, les dépendances, lancer
l'app) va maintenant être décrit dans un fichier.

### 1.3 Écrire le Dockerfile

Créez une branche et le fichier `Dockerfile` à la racine du dépôt :

```bash
git switch -c feature/docker
```

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 5000
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:create_app()"]
```

> Ce Dockerfile est volontairement simple. Vous l'améliorerez dans la partie 2.

### 1.4 Construire et lancer

```bash
docker build -t formini-tasks:0.1 .
docker images formini-tasks
docker run -d --name tasks -p 5000:5000 formini-tasks:0.1
docker logs tasks                        # gunicorn : "Listening at: http://0.0.0.0:5000"
curl -s localhost:5000/health
```

Sortie attendue :

```json
{"database":"ok","status":"ok","version":"dev"}
```

Ouvrez `http://<ip-de-votre-vm>:5000` dans le navigateur du poste Formini : ajoutez
deux tâches.

### 1.5 Inspecter l'image

```bash
docker history formini-tasks:0.1         # une ligne par instruction, avec sa taille
docker exec tasks whoami                 # root (à corriger cet après-midi)
docker exec tasks ls -la /app            # .venv ? .git ? tasks.db ?
docker image inspect formini-tasks:0.1 --format '{{.Size}}' | numfmt --to=iec
```

Notez : la taille de l'image, l'utilisateur, et les fichiers qui n'ont rien à faire
dans l'image.

### 1.6 Pousser la branche

```bash
git add Dockerfile
git commit -m "feat(docker): ajoute un premier Dockerfile"
git push -u origin feature/docker
```

Ouvrez une pull request dans Gitea. **Ne la fusionnez pas encore** : vous allez
l'améliorer.

### Bonus partie 1

- Lancez un deuxième conteneur de la même image sur le port 5001.
- Limitez la mémoire : `docker run --rm -p 5002:5000 --memory 128m formini-tasks:0.1`
  puis `docker stats`.

---

## Partie 2 — Défi : l'application et sa base, publiées

Répartissez-vous le travail dans l'équipe : une personne sur le Dockerfile, une sur
Compose, une sur le registre et la PR. Tout se passe sur la branche `feature/docker`.

### 2.1 Améliorer le Dockerfile

Faites évoluer le Dockerfile pour qu'il respecte, dans l'ordre :

1. **Cache** : `COPY requirements.txt` et `pip install` **avant** `COPY` du code.
2. **Contexte propre** : un `.dockerignore` qui exclut `.git`, `.venv`, `__pycache__`,
   `*.db`, `.env`, `tests/`, `ateliers/`.
3. **Utilisateur non-root** : `useradd` + `USER app`.
4. **`HEALTHCHECK`** qui appelle `/health`.
5. **`ENV PYTHONUNBUFFERED=1`** pour des journaux immédiats.

Vérifiez :

```bash
docker build -t formini-tasks:0.2.0 .
docker image inspect formini-tasks:0.2.0 --format '{{.Size}}' | numfmt --to=iec   # < 200M
docker run --rm formini-tasks:0.2.0 whoami                                          # app
docker run --rm formini-tasks:0.2.0 ls -la /app                                     # pas de .venv ni .git
```

Chronométrez : modifiez un commentaire dans `app.py`, relancez `docker build`.
Seules les couches après `COPY app.py` doivent être reconstruites.

### 2.2 Écrire compose.yaml

Créez `compose.yaml` avec deux services :

| Service | Image / build        | Points obligatoires                                                        |
|---------|----------------------|----------------------------------------------------------------------------|
| `web`   | `build: .`           | port `8000:5000`, `DATABASE_URL` vers `db`, `depends_on` avec `service_healthy` |
| `db`    | `postgres:16-alpine` | `POSTGRES_*` depuis `.env`, volume nommé `pgdata`, `healthcheck` `pg_isready` |

Créez `.env.example` (versionné) et `.env` (ignoré par Git) :

```bash
cp .env.example .env     # puis changez le mot de passe
```

```bash
docker compose up -d --build
docker compose ps        # les deux services doivent afficher (healthy)
docker compose logs web  # pas d'erreur de connexion
curl -s localhost:8000/health
```

Sortie attendue : `"database":"ok"`.

### 2.3 Prouver la persistance

```bash
curl -s -X POST localhost:8000/api/tasks -H 'Content-Type: application/json' \
  -d '{"title":"Publier l image"}'
docker compose down
docker compose up -d
curl -s localhost:8000/api/tasks         # la tâche est toujours là
```

Puis, pour comprendre : `docker compose down -v`, `up -d`, la liste est vide.

### 2.4 Publier dans le registre Gitea

1. Dans Gitea : avatar → **Settings** → **Applications** → *Generate Token*, nom
   `docker`, portée **package** en lecture/écriture. Copiez le jeton.
2. Sur la VM :

```bash
docker login gitea.formini.local:3000 -u <votre-login>      # mot de passe = le jeton
SHA=$(git rev-parse --short HEAD)
docker tag formini-tasks:0.2.0 gitea.formini.local:3000/equipe-a/formini-tasks:0.2.0
docker tag formini-tasks:0.2.0 gitea.formini.local:3000/equipe-a/formini-tasks:$SHA
docker push gitea.formini.local:3000/equipe-a/formini-tasks:0.2.0
docker push gitea.formini.local:3000/equipe-a/formini-tasks:$SHA
```

   Le script `solution/push-registry.sh` automatise ces lignes.
3. Vérifiez dans Gitea : organisation `equipe-a` → onglet **Packages** → `formini-tasks`
   → deux tags.

### 2.5 Fusionner et vérifier chez un coéquipier

```bash
git add Dockerfile .dockerignore compose.yaml .env.example
git commit -m "feat(docker): image durcie, compose web+db, publication registre"
git push
```

Revue de la PR par un coéquipier, puis fusion. Un **autre** membre de l'équipe, sur sa
VM, lance l'image depuis le registre sans la construire :

```bash
docker run -d -p 9000:5000 gitea.formini.local:3000/equipe-a/formini-tasks:0.2.0
curl -s localhost:9000/health
```

### Critères de réussite

- [ ] `docker compose ps` : `web` et `db` en état `healthy`.
- [ ] Image < 200 Mo ; `whoami` dans le conteneur ≠ `root`.
- [ ] `.env` absent de Git, `.env.example` présent.
- [ ] Image visible dans Gitea → Packages avec deux tags (`0.2.0` et le SHA).
- [ ] PR `feature/docker` fusionnée après revue ; branche supprimée.

### Bonus partie 2

- **Multi-stage** : écrivez une variante `Dockerfile.multistage` (voir diapositive) et
  comparez `docker images`.
- **Autres langages** : quatre Dockerfiles commentés (Go, Python/FastAPI, React, Rust) dans
  [`exemples/`](exemples/README.md). Choisissez celui de votre contexte, construisez-le et faites
  son exercice.
- **Piles complètes** : un `compose.yaml` par langage dans `exemples/stack-*/` (front React,
  API Go, Python, Node ou Rust, PostgreSQL, Redis), par exemple
  [`exemples/stack-go/`](exemples/stack-go/README.md). Exercices : réplication de l'API, panne
  du cache, publication des images.
- **Analyse de vulnérabilités** : `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.58.0 image formini-tasks:0.2.0`
  (ou `docker scout quickview formini-tasks:0.2.0` si disponible). Combien de CVE
  critiques ? Combien avec `python:3.12` au lieu de `-slim` ?
- Ajoutez un service `adminer` (image `adminer:4`) sur le port 8081 pour explorer la base.

---

## Dépannage

| Message                                                   | Cause                                                | Correction                                                          |
|-----------------------------------------------------------|------------------------------------------------------|---------------------------------------------------------------------|
| `permission denied while trying to connect to the Docker daemon` | utilisateur hors du groupe `docker`            | `sudo usermod -aG docker $USER`, nouvelle session                   |
| `connection refused` / `could not connect to server` dans les logs web | `localhost` dans `DATABASE_URL`, ou db pas prête | hôte `db`, `depends_on: condition: service_healthy`         |
| `password authentication failed for user "formini"`       | `.env` modifié après la première création du volume  | `docker compose down -v` puis `up -d` (données perdues)             |
| `Bind for 0.0.0.0:8000 failed: port is already allocated` | un autre conteneur utilise le port                   | `docker ps`, `docker rm -f <nom>` ou changez le port hôte           |
| `http: server gave HTTP response to HTTPS client`         | registre HTTP non déclaré                            | vérifier `/etc/docker/daemon.json` contient `insecure-registries`, `sudo systemctl restart docker` |
| `unauthorized: authentication required` au push           | pas de `docker login`, ou jeton sans portée package  | regénérer le jeton, `docker login` à nouveau                        |
| `denied: ... not allowed to push`                         | vous n'êtes pas membre de l'organisation             | demander au formateur de vous ajouter à `equipe-a`                  |
| état `unhealthy`                                          | le healthcheck échoue                                | `docker inspect --format '{{json .State.Health}}' <conteneur>`      |
| image de 900 Mo                                           | `.venv` / `.git` copiés                              | `.dockerignore`, puis `docker history`                              |
| `COPY failed: file not found`                             | `docker build` lancé depuis le mauvais dossier       | se placer à la racine du dépôt, le `.` final est le contexte        |

Solution de référence : `ateliers/jour2-docker/solution/`.
