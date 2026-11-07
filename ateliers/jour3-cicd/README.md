# Atelier Jour 3 — Pipelines CI/CD avec Gitea Actions

**Mardi 10 novembre 2026 · Formation DevOps Formini**

À la fin de cet atelier, chaque commit poussé sur votre dépôt `formini-tasks`
déclenche automatiquement le lint, les tests, la construction de l'image Docker,
son analyse de sécurité et sa publication dans le registre Gitea.

---

## Objectifs

- Écrire un workflow Gitea Actions et le lire dans l'interface.
- Faire échouer une pull request quand les tests cassent.
- Construire, analyser et publier une image sans taper une seule commande à la main.
- Protéger `main` pour que rien ne soit fusionné sans pipeline vert.
- Livrer une version numérotée avec un tag Git.

## Prérequis

| Élément | Comment vérifier |
|---------|------------------|
| Dépôt `formini-tasks` dans l'organisation de votre équipe sur Gitea, avec le `Dockerfile` du jour 2 | `git clone http://gitea.formini.local:3000/equipe-a/formini-tasks.git` puis `docker build -t test .` |
| Runner `act_runner` enregistré sur votre VM (voir `setup/act-runner/`) | `sudo systemctl status act_runner` → *active (running)* |
| Docker autorisé à parler au registre Gitea en HTTP | `cat /etc/docker/daemon.json` contient `"insecure-registries": ["gitea.formini.local:3000"]` |
| trivy installé | `trivy --version` |
| Node.js 20 installé (nécessaire à `actions/checkout`) | `node --version` |

Conventions utilisées dans cette fiche :

- Gitea : `http://gitea.formini.local:3000`
- Organisation : `equipe-a` (remplacez par la vôtre)
- Image : `gitea.formini.local:3000/equipe-a/formini-tasks`
- Utilisateur sur la VM : `devops`

---

## Partie 1 — Atelier guidé (10:45 – 12:00) : tester chaque commit

### 1.1 Activer les Actions sur le dépôt

1. Ouvrir le dépôt dans Gitea → **Paramètres** → **Dépôt**.
2. Dans la section *Unités de dépôt*, cocher **Actions**, puis **Mettre à jour**.
3. Un onglet **Actions** apparaît dans la barre du dépôt. Il est vide pour l'instant.

### 1.2 Vérifier que votre runner est en ligne

1. **Paramètres** → **Actions** → **Runners**.
2. Votre VM doit apparaître avec un point vert et l'étiquette `ubuntu-latest`.
3. Si elle est absente ou grise :

```bash
sudo systemctl restart act_runner
journalctl -u act_runner -n 30 --no-pager
```

> Un runner hors ligne ne provoque pas d'erreur : les jobs restent simplement
> « en attente » pour toujours. C'est la première chose à vérifier.

### 1.3 Écrire le workflow

Sur votre VM, dans le clone du dépôt :

```bash
cd ~/formini-tasks
git switch -c ci/pipeline-test
mkdir -p .gitea/workflows
```

Créer `.gitea/workflows/ci.yml` :

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Dépendances
        run: |
          python3 -m venv .venv
          .venv/bin/pip install -q -r requirements-dev.txt

      - name: Lint
        run: .venv/bin/flake8 .

      - name: Tests
        run: .venv/bin/pytest -q
```

Lire le fichier avant de le pousser, et répondre à voix haute aux quatre questions :
**quand** (`on`), **quoi** (`jobs`), **où** (`runs-on`), **comment** (`steps`).

> **Indentation YAML :** deux espaces, jamais de tabulation. Une erreur d'indentation
> empêche Gitea de lire le fichier : aucun run n'apparaît, sans message d'erreur.

### 1.4 Pousser et observer

```bash
git add .gitea/workflows/ci.yml
git commit -m "ci: ajoute le pipeline de tests"
git push -u origin ci/pipeline-test
```

1. Ouvrir une pull request vers `main` dans Gitea.
2. Dans la PR, une ligne de statut apparaît : **CI / test (pull_request)** avec un
   rond jaune (en cours), puis une coche verte.
3. Onglet **Actions** → cliquer sur le run → cliquer sur le job `test` → déplier
   chaque step et lire sa sortie.

Questions à vous poser :

- Combien de temps a pris le run ? (cible : moins de deux minutes)
- Quel step a été le plus long ? Pourquoi ?

### 1.5 Casser un test, volontairement

Dans `tests/test_api.py`, modifier une assertion pour qu'elle soit fausse, par exemple :

```python
def test_liste_vide(client):
    r = client.get("/api/tasks")
    assert r.status_code == 418   # volontairement faux
```

```bash
git commit -am "test: casse volontairement un test"
git push
```

1. Retourner sur la PR : le statut passe au rouge.
2. Ouvrir le run, trouver le step en échec, lire **la dernière ligne** du journal.
3. Corriger le test, commiter, pousser. Le statut repasse au vert.
4. Fusionner la PR. Un nouveau run se déclenche sur `main` (événement `push`).

### Critères de réussite de la partie 1

- [ ] Un run vert sur la pull request, puis sur `main` après fusion.
- [ ] Vous avez vu un run rouge et su dire quel step et quelle ligne l'ont provoqué.
- [ ] Moins de deux minutes par run.

**Bonus partie 1 :** publier le rapport de tests comme artefact.

```yaml
      - name: Tests
        run: .venv/bin/pytest -q --junitxml=report.xml

      - name: Rapport de tests
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: rapport-tests
          path: report.xml
```

Le fichier devient téléchargeable depuis la page du run. `if: always()` le publie
même quand les tests échouent, ce qui est précisément le moment où l'on en a besoin.

---

## Partie 2 — Défi en autonomie (14:00 – 15:30) : construire, analyser, publier

Par équipe. Objectif : chaque push sur `main` produit une image analysée et publiée
dans le registre Gitea, et une pull request cassée ne peut pas être fusionnée.

### 2.1 Créer les secrets

1. **Jeton d'accès** : avatar → **Paramètres** → **Applications** → *Gérer les jetons d'accès*.
   Nom : `ci-registry`. Permissions : **package → Read and Write**. Copier le jeton :
   il ne sera plus jamais affiché.
2. **Secrets du dépôt** : dépôt → **Paramètres** → **Actions** → **Secrets** → *Ajouter un secret* :
   - `REGISTRY_USER` : votre nom d'utilisateur Gitea
   - `REGISTRY_TOKEN` : le jeton copié à l'étape 1

> Un secret d'**organisation** (Organisation → Paramètres → Actions → Secrets) est
> partagé par tous les dépôts de l'équipe. Pratique si plusieurs projets publient
> dans le même registre.

Vérifier le jeton à la main avant de l'utiliser dans le pipeline :

```bash
echo "<JETON>" | docker login gitea.formini.local:3000 -u <utilisateur> --password-stdin
docker logout gitea.formini.local:3000
```

### 2.2 Ajouter le job `build`

Compléter `ci.yml` avec un deuxième job, qui attend que `test` soit vert et ne tourne
que sur un push vers `main` (pas sur les pull requests) :

```yaml
env:
  REGISTRY: gitea.formini.local:3000
  IMAGE: gitea.formini.local:3000/equipe-a/formini-tasks

jobs:
  test:
    # ... inchangé ...

  build:
    runs-on: ubuntu-latest
    needs: test
    if: gitea.event_name == 'push'
    steps:
      - uses: actions/checkout@v4

      - name: Étiquette = SHA court du commit
        run: echo "TAG=$(echo '${{ gitea.sha }}' | cut -c1-7)" >> "$GITHUB_ENV"

      - name: Construction de l'image
        run: docker build -t "$IMAGE:$TAG" .

      - name: Analyse de sécurité (bloquante sur CRITICAL)
        run: trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE:$TAG"

      - name: Connexion au registre
        run: echo "${{ secrets.REGISTRY_TOKEN }}" | docker login "$REGISTRY" -u "${{ secrets.REGISTRY_USER }}" --password-stdin

      - name: Publication
        run: |
          docker push "$IMAGE:$TAG"
          docker tag "$IMAGE:$TAG" "$IMAGE:latest"
          docker push "$IMAGE:latest"

      - name: Déconnexion
        if: always()
        run: docker logout "$REGISTRY"
```

Points à comprendre :

- `needs: test` : si les tests échouent, `build` n'est même pas lancé.
- `if: gitea.event_name == 'push'` : on ne publie pas les brouillons des PR.
- `$GITHUB_ENV` : un step écrit une variable, les steps suivants la lisent.
- `--password-stdin` : le jeton ne transite ni par la ligne de commande ni par les logs.
- **Pourquoi scan et publication sont des steps du même job, et non des jobs séparés ?**
  En mode *host*, chaque job peut être pris par n'importe quel runner libre de
  l'équipe, donc par une autre VM, qui n'a pas l'image en local. Dans un seul job,
  tous les steps tournent sur la même machine et partagent le même démon Docker.

Pousser via une pull request (le pipeline relit son propre fichier), fusionner, puis
vérifier :

1. Onglet **Actions** : le run sur `main` a deux jobs, `test` puis `build`.
2. Organisation → **Paquets** : l'image `formini-tasks` apparaît avec deux étiquettes,
   `<sha>` et `latest`.
3. Depuis la VM d'un coéquipier :

```bash
docker pull gitea.formini.local:3000/equipe-a/formini-tasks:latest
docker run --rm -p 8080:5000 gitea.formini.local:3000/equipe-a/formini-tasks:latest
curl http://localhost:8080/health
```

### 2.3 Protéger `main`

Dépôt → **Paramètres** → **Branches** → *Ajouter une règle* :

| Champ | Valeur |
|-------|--------|
| Motif de nom de branche protégée | `main` |
| Activer le push | **décoché** (personne ne pousse directement) |
| Activer la vérification de statut | **coché**, motif : `CI / test*` |
| Approbations requises | `1` |
| Bloquer la fusion en cas de demandes de modifications | coché |

Tester : ouvrir une PR avec un test cassé. Le bouton **Fusionner** doit être grisé
avec le message *statut requis manquant*, même pour le propriétaire du dépôt.

### 2.4 Livrer une version

Créer `.gitea/workflows/release.yml` (voir `solution/.gitea/workflows/release.yml`) :
il se déclenche sur un tag `v*`, construit, analyse et publie l'image avec le nom du
tag comme étiquette.

```bash
git switch main && git pull
git tag -a v1.0.0 -m "Première version livrée"
git push origin v1.0.0
```

Dans **Paquets**, l'étiquette `v1.0.0` apparaît. Depuis n'importe quelle VM :

```bash
docker pull gitea.formini.local:3000/equipe-a/formini-tasks:v1.0.0
```

### Critères de réussite de la partie 2

- [ ] Un push sur `main` produit une image `:<sha>` et `:latest` dans le registre.
- [ ] Une PR dont les tests échouent ne peut pas être fusionnée, même par un admin.
- [ ] `docker pull …:v1.0.0` fonctionne depuis une autre VM de l'équipe.
- [ ] Aucun secret n'apparaît dans le dépôt ni dans les journaux (chercher `***`).

### Bonus

1. **Audit des dépendances** : un step `pip-audit` dans le job `test`.
   ```yaml
   - name: Audit des dépendances
     run: |
       .venv/bin/pip install -q pip-audit
       .venv/bin/pip-audit -r requirements.txt
   ```
2. **Cache pip** : réutiliser `.venv` entre deux runs avec `actions/cache@v4`, clé
   basée sur `hashFiles('requirements-dev.txt')`. Mesurer le gain de temps.
3. **Matrice de versions** : tester sur Python 3.11 et 3.12 avec `strategy.matrix`.
   En mode host, il faut que les deux interpréteurs soient installés sur la VM
   (`sudo apt install python3.11-venv`), ou enregistrer une étiquette docker
   `python:docker://python:3.11` sur le runner.
4. **Modèle de pull request** : copier `solution/.gitea/pull_request_template.md`
   pour que chaque PR rappelle la liste de vérification.
5. **Notification** : un dernier step qui appelle un webhook (Mattermost, Slack,
   Discord…) avec `curl` quand `build` échoue (`if: failure()`).

---

## Dépannage

| Symptôme | Cause probable | Remède |
|----------|----------------|--------|
| Aucun run n'apparaît après un push | Actions non activées sur le dépôt, ou YAML invalide | Paramètres → Dépôt → Actions ; vérifier l'indentation avec `python3 -c "import yaml,sys; yaml.safe_load(open('.gitea/workflows/ci.yml'))"` |
| Le job reste « en attente » | Runner hors ligne, ou étiquette `runs-on` sans correspondance | `systemctl status act_runner` ; comparer `runs-on` avec les étiquettes dans Paramètres → Actions → Runners |
| `actions/checkout` échoue : `node: not found` | Node.js absent sur la VM (mode host) | `node --version` ; sinon réinstaller avec `setup/act-runner/install-runner.sh` |
| `docker login` : `unauthorized` | Jeton sans le droit *package write*, ou mauvais nom d'utilisateur | Recréer le jeton avec la bonne permission ; `REGISTRY_USER` = login Gitea, pas l'e-mail |
| `docker push` : `http: server gave HTTP response to HTTPS client` | Registre non déclaré comme non sécurisé | Ajouter `"insecure-registries": ["gitea.formini.local:3000"]` dans `/etc/docker/daemon.json`, puis `sudo systemctl restart docker` |
| `trivy` échoue avec une erreur de téléchargement | Base de vulnérabilités non mise à jour, pas d'accès Internet | `trivy image --download-db-only` une fois, puis relancer |
| trivy bloque sur une faille du système de base | Image de base ancienne | Reconstruire avec `docker build --pull`, ou passer à une étiquette plus récente de `python:3.12-slim` |
| Le bouton Fusionner reste actif malgré un test rouge | Motif de statut incorrect | Le contexte s'appelle `CI / test (pull_request)` : utiliser le motif `CI / test*` |
| `permission denied` sur `/var/run/docker.sock` | L'utilisateur du runner n'est pas dans le groupe `docker` | `sudo usermod -aG docker devops`, puis `sudo systemctl restart act_runner` |

Les fichiers complets et commentés sont dans `solution/`.
