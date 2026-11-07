# Guide formateur — Jour 3 : Pipelines CI/CD avec Gitea Actions

**Mardi 10 novembre 2026 · 09:00 – 16:00 · Formation DevOps Formini**

Support : `slides/jour3-cicd-gitea-actions.html` (31 diapositives, notes orateur
avec la touche **S**). Fiche participant : `ateliers/jour3-cicd/README.md`.
Solutions : `ateliers/jour3-cicd/solution/`.

Objectif de la journée : à 16:00, chaque équipe a un dépôt dont chaque push sur
`main` lint, teste, construit, analyse et publie l'image dans le registre Gitea, et
dont la branche `main` refuse toute fusion sans pipeline vert.

---

## La veille, ou avant 08:30

Tout vérifier **sur la VM formateur et sur une VM participant**.

| Vérification | Commande / endroit | Attendu |
|--------------|--------------------|---------|
| Gitea répond | `curl -s http://gitea.formini.local:3000/api/healthz` | `"status":"pass"` |
| Actions activées au niveau instance | Administration → Configuration → *Actions enabled* | `true` |
| Runners en ligne | Administration → **Actions** → **Runners** | un runner par VM participant, point vert, étiquette `ubuntu-latest` |
| Service runner | `sudo systemctl status act_runner` sur une VM participant | *active (running)* |
| Node.js (mode host, requis par `actions/checkout`) | `node --version` | `v20.x` |
| trivy et sa base | `trivy image --download-db-only` | télécharge sans erreur |
| Registre non sécurisé | `docker info \| grep -A1 Insecure` | `gitea.formini.local:3000` |
| Connexion au registre | `echo <jeton> \| docker login gitea.formini.local:3000 -u formateur --password-stdin` | *Login Succeeded* |
| Dépôt de démo | `formateur/formini-tasks` sur Gitea, avec le `Dockerfile` du jour 2 et un pipeline **déjà vert** | à montrer en 09:40 |
| Dépôt « cassé » | une branche `demo/test-casse` avec un test faux, PR ouverte, run rouge | à montrer en 10:10 |

Avoir sous la main : le jeton `ci-registry` du compte formateur, un terminal
ouvert sur la VM formateur, l'onglet Actions du dépôt de démo.

Si un runner participant est hors ligne au matin : `sudo systemctl restart act_runner`
puis `journalctl -u act_runner -n 30`. Si l'enregistrement est perdu, relancer
`setup/act-runner/install-runner.sh` avec un nouveau jeton d'enregistrement
(Administration → Actions → Runners → *Créer un jeton d'enregistrement*).

---

## 09:00 – 09:15 · Ouverture (diapos 1 à 3)

- Accueil, tour rapide : « Qui a son image Docker d'hier ? Qui l'a poussée dans le
  registre à la main ? » Les mains levées sont la transition : *aujourd'hui, c'est
  la dernière fois que vous la poussez à la main.*
- Diapo 2 : la semaine. Le pipeline d'aujourd'hui produit l'image que Kubernetes
  tirera demain. Chaque jour empile sur le précédent.
- Diapo 3 : agenda. Annoncer la règle de la journée : **un pipeline simple et vert
  avant un pipeline ambitieux**.

## 09:15 – 09:45 · Partie 1 : intégration et livraison continues (diapos 4 à 9)

**Points à faire passer**

- Diapo 5 : l'enfer de l'intégration. Raconter une release de six semaines. Demander
  « qui a déjà eu un build que seule une personne savait lancer ? ». Toujours quelqu'un.
- Diapo 6 : CI / livraison continue / déploiement continu. Question clé pour
  distinguer les deux CD : *qui appuie sur le bouton ?* Annoncer : ce matin CI, cet
  après-midi livraison, demain déploiement.
- Diapo 7 : dix minutes et petits lots. Relier aux métriques DORA du jour 1.
  Écrire au tableau et laisser toute la journée : **rouge sur main = priorité absolue**.
- Diapo 8 : les six étapes. Insister sur l'ordre, du moins cher au plus cher.
  Publication sur `main` seulement.
- Diapo 9 : des questions, pas des outils. Faire dire à la salle quel outil
  répondrait à chaque question dans *leur* langage (Java, PHP, Node…).

**Question à poser** : « Entre un commit et la certitude qu'il ne casse rien, il se
passe combien de temps chez vous aujourd'hui ? » Noter les réponses, y revenir au
bilan.

## 09:45 – 10:30 · Partie 2 : Gitea Actions (diapos 10 à 16)

**Démo 1 (09:50, diapo 11) — lire un workflow.** Ouvrir
`.gitea/workflows/ci.yml` du dépôt de démo dans VS Code. Lire de haut en bas avec
les quatre questions : quand, quoi, où, comment. Ne pas expliquer les mots-clés un
par un : la diapo 12 est une référence, on y reviendra pendant l'atelier.

**Démo 2 (10:00, diapo 13 et 15) — le runner.** Sur la VM formateur :

```bash
sudo systemctl status act_runner
sudo cat /etc/act_runner/config.yaml | grep -A3 labels
journalctl -u act_runner -f
```

Puis dans Gitea : Administration → Actions → Runners. Montrer le point vert, les
étiquettes, la date de dernier contact. Faire le lien : *le runner interroge Gitea,
pas l'inverse*. Couper le runner (`sudo systemctl stop act_runner`), pousser un
commit vide sur le dépôt de démo :

```bash
git commit --allow-empty -m "ci: déclenche un run" && git push
```

Montrer le job **en attente**. Relancer le runner, le job démarre. C'est la panne
numéro un de la journée : la montrer avant qu'elle arrive.

**Démo 3 (10:15, diapo 16) — lire un run rouge.** Ouvrir la PR `demo/test-casse`.
Croix rouge dans la PR → onglet Actions → job `test` → step « Tests » déplié →
**dernière ligne** du journal. Rejouer la commande du step sur la VM :

```bash
.venv/bin/pytest -q
```

Même erreur, même ligne. Message : chaque step est une commande que l'on peut
taper soi-même.

**Diapo 14 (étiquettes)** : expliquer en deux minutes pourquoi on est en mode host
(rapide, transparent) et pourquoi la production préfère le mode docker (isolation).

## 10:30 – 10:45 · Pause

Pendant la pause : vérifier dans Administration → Runners que tous les runners
participants sont toujours verts.

## 10:45 – 12:00 · Atelier guidé : un premier pipeline (diapo 17)

Fiche participant, **partie 1**. Rester sur la diapo 17.

**Déroulé conseillé**

| Heure | Étape | Ce que fait le formateur |
|-------|-------|--------------------------|
| 10:45 | 1.1 – 1.2 activer les Actions, vérifier le runner | Faire la manipulation au projecteur une fois, puis laisser faire. Passer voir ceux qui ne voient pas l'onglet Actions. |
| 10:55 | 1.3 écrire `ci.yml` | Projeter le fichier. Prévenir sur l'indentation. Circuler. |
| 11:10 | 1.4 pousser, PR, observer | Premier run vert attendu vers 11:15. Demander à chacun le temps du run. |
| 11:25 | 1.5 casser un test | Le moment le plus utile : chacun doit **lire** son run rouge. Interroger trois personnes : « quelle ligne ? » |
| 11:45 | fusion, run sur `main`, bonus artefact | Les rapides font le bonus. |
| 11:55 | synthèse | Compter les pipelines verts à main levée. |

**Pannes attendues et réponses**

- *Aucun run n'apparaît* → Actions non activées sur le dépôt, ou YAML mal indenté.
  `python3 -c "import yaml; yaml.safe_load(open('.gitea/workflows/ci.yml'))"`.
- *Job en attente* → runner hors ligne, ou `runs-on` qui ne correspond pas à
  l'étiquette. Montrer où comparer.
- *`node: not found` dans `actions/checkout`* → Node absent sur la VM ; relancer le
  script d'installation du runner.
- *flake8 rouge sur une ligne trop longue* → c'est voulu, c'est le lint qui fait son
  travail. Corriger ou ajuster `.flake8`.
- *`pip install` très lent* → première exécution, pas de cache ; évoquer le bonus
  cache de l'après-midi.

## 12:00 – 13:00 · Pause déjeuner

Relancer les runners tombés. Préparer le jeton de démo pour les secrets.

## 13:00 – 13:35 · Partie 3 : secrets et sécurité (diapos 18 à 23)

**Diapo 19 — jamais dans le code.** Raconter les clés AWS commitées et la facture
du lendemain. Insister : un secret commité se **révoque**, il ne se cache pas.

**Démo 4 (13:10, diapo 20) — secrets dans Gitea.**

1. Avatar → Paramètres → Applications → jeton `ci-registry`, permission *package :
   Read and Write*. Montrer que le jeton ne s'affiche qu'une fois.
2. Dépôt → Paramètres → Actions → Secrets → `REGISTRY_USER`, `REGISTRY_TOKEN`.
3. Ajouter temporairement au workflow de démo un step
   `run: echo "${{ secrets.REGISTRY_TOKEN }}"`, pousser, ouvrir le journal : `***`.
4. **Supprimer ce step** devant la salle en expliquant pourquoi : on ne laisse pas
   traîner un echo de secret, même masqué (un `echo` avec `base64` le dévoilerait).

**Démo 5 (13:20, diapos 21-22) — trivy sur l'image d'hier.**

```bash
trivy image gitea.formini.local:3000/formateur/formini-tasks:latest
trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 gitea.formini.local:3000/formateur/formini-tasks:latest
echo $?
```

Expliquer `--ignore-unfixed` : sans lui, le pipeline serait rouge en permanence sur
des failles de l'OS de base sans correctif. Le remède habituel à une faille
critique : `docker build --pull` sur une image de base à jour.

**Démo 6 (13:30, diapo 23) — protéger `main`.** Dépôt → Paramètres → Branches →
règle `main` : push désactivé, statut requis `CI / test*`, une approbation. Ouvrir
la PR `demo/test-casse` : bouton Fusionner grisé, *statut requis manquant*. Message :
*personne ne contourne les tests, pas même l'admin*. Préciser le nom exact du
contexte : `CI / test (pull_request)`, d'où le motif `CI / test*`.

## 13:35 – 14:00 · Partie 4 : stratégies de livraison (diapos 24 à 28)

- Diapo 25 : trois étiquettes, trois usages. Le piège de `latest` : deux machines,
  deux images, personne ne le sait. Demain Kubernetes déploiera toujours une
  étiquette précise.
- Diapo 26 : `release.yml` sur tag. Montrer un tag en direct sur le dépôt de démo :

```bash
git tag -a v1.0.0 -m "Première version" && git push origin v1.0.0
```

  Pendant que le run tourne, passer à la diapo 27.
- Diapo 27 : construire une fois, déployer partout. Ce qui change entre les
  environnements, c'est la configuration, jamais l'image. Revenir à Compose d'hier
  (`DATABASE_URL`).
- Diapo 28 : bonnes pratiques. Revenir au dépôt de démo : l'image `v1.0.0` est dans
  Paquets. Demander : « laquelle de ces pratiques manque le plus dans vos projets ? »

Annoncer le défi : viser d'abord un `build` qui marche, puis la protection, puis le
tag. Les bonus après.

## 14:00 – 15:30 · Défi en autonomie (diapo 29)

Fiche participant, **partie 2**. Mêmes équipes qu'hier.

| Heure | Jalon attendu | Où intervenir |
|-------|---------------|---------------|
| 14:00 – 14:15 | 2.1 jeton et secrets créés, `docker login` manuel réussi | Jetons sans *package write* ; `REGISTRY_USER` = login, pas e-mail ; membres de l'organisation sans droit d'écriture sur les paquets. |
| 14:15 – 14:45 | 2.2 job `build` vert, image `:<sha>` et `:latest` dans Paquets | `http: server gave HTTP response` → registre non déclaré dans `daemon.json`. `permission denied` sur le socket Docker → groupe `docker`. trivy rouge → `--pull` ou image de base plus récente. |
| 14:45 – 15:00 | 2.3 `main` protégée, PR cassée non fusionnable | Motif de statut : `CI / test*`. Tester avec un compte non admin si possible. |
| 15:00 – 15:15 | 2.4 tag `v1.0.0`, `docker pull …:v1.0.0` depuis une autre VM | Tag poussé mais pas de run → `on.push.tags` absent ou tag non annoté poussé avant le workflow. |
| 15:15 – 15:30 | Démonstration | Une équipe montre au projecteur : push → run → Paquets → pull depuis une autre VM. |

**Question à poser aux équipes qui ont fini tôt** : « Pourquoi scan et publication
sont-ils des steps du même job plutôt que des jobs séparés ? » La réponse (runners
sur des VM différentes, démons Docker différents) est dans la fiche ; vérifier
qu'ils l'ont comprise, puis les lancer sur le bonus cache ou pip-audit.

**Tampon** : si les équipes sont en retard à 15:00, abandonner 2.4 (le tag) et le
faire en démo au bilan. La protection de branche est plus importante que le tag.

## 15:30 – 16:00 · Bilan (diapos 30 et 31)

- Diapo 30 : trois choses à retenir. Reprendre les réponses notées à 09:30 (« combien
  de temps entre un commit et la certitude ») : maintenant, c'est le temps du run.
- Tour de table : une chose apprise, une chose encore floue. Noter les points flous
  pour les reprendre demain matin.
- Rappels logistiques :
  - **Ne pas éteindre les VM** : runners et registre servent demain.
  - Chaque équipe doit avoir au moins une image `v1.0.0` dans Paquets : c'est celle
    que Kubernetes déploiera demain.
- Annoncer demain : Terraform et Ansible le matin, Kubernetes l'après-midi.
  Prérequis demain matin : les identifiants AWS de la formation seront distribués à
  09:00.

---

## Pièges connus (résumé)

| Piège | Signal | Parade |
|-------|--------|--------|
| Runner hors ligne | job « en attente » sans fin | `systemctl restart act_runner` ; vérifier dans Administration → Runners |
| Étiquette qui ne correspond pas | idem | `runs-on: ubuntu-latest` et étiquette `ubuntu-latest:host` |
| Jeton mal scopé | `unauthorized` au `docker login` | permission *package : Read and Write* |
| Registre HTTP non déclaré | `http: server gave HTTP response to HTTPS client` | `insecure-registries` dans `/etc/docker/daemon.json` + restart docker |
| Jobs séparés en mode host | `image not found` au scan ou au push | un seul job pour build + scan + push |
| Motif de statut faux | fusion possible malgré un test rouge | `CI / test*` |
| Node absent | `node: not found` dans checkout | Node.js 20 sur la VM |
| YAML avec tabulations | aucun run n'apparaît | deux espaces ; valider avec `yaml.safe_load` |

## Minutage de secours

Si la matinée déborde : couper la diapo 9 (questions par étape) et la diapo 14
(modes host / docker) à une phrase chacune. Si l'après-midi déborde : le tag
`v1.0.0` passe en démo formateur au bilan. Ne jamais sacrifier 1.5 (casser un test)
ni 2.3 (protection de branche) : ce sont les deux moments où l'on comprend à quoi
sert un pipeline.
