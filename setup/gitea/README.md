# Gitea — serveur de la formation

Gitea tourne sur la **VM formateur** et sert de forge Git, de registre de conteneurs (jour 2) et de moteur CI (jour 3).

## Installation (J-1)

```bash
# sur la VM formateur, Docker déjà installé (setup/install-vm.sh)
cd setup/gitea
docker compose up -d
docker compose logs -f gitea      # attendre "Listen: http://0.0.0.0:3000"
```

Ouvrez `http://<ip-formateur>:3000` : l'installation est verrouillée (`INSTALL_LOCK`), il n'y a pas d'assistant. Créez les comptes avec le script :

```bash
sudo apt install -y jq
ADMIN_PASS='ChangezMoi!2026' bash bootstrap.sh participants.csv
```

Le script crée :

- l'administrateur `formateur` ;
- un compte par ligne de `participants.csv` (mot de passe initial `Formini2026!`, changement forcé) ;
- une organisation par équipe (`equipe-a`, `equipe-b`, …), chaque membre dans l'équipe *Owners* ;
- et affiche un **jeton d'enregistrement act_runner** à conserver pour `setup/act-runner/install-runner.sh`.

## Dépôt de la formation

Poussez ce dossier complet dans un dépôt `formation-devops` sous l'organisation `formini` (créez-la dans l'interface) : les participants y trouveront les fiches, le code de départ et les solutions que vous choisirez de rendre visibles.

```bash
cd "<ce dossier>"
git init && git add . && git commit -m "chore: matériel de formation"
git remote add origin http://gitea.formini.local:3000/formini/formation-devops.git
git push -u origin main
```

## Résolution de nom

Les postes et les VM doivent résoudre `gitea.formini.local` vers l'IP de la VM formateur :

- VM : fait par `install-vm.sh` (`GITEA_IP=...`) ;
- postes Formini Windows : `C:\Windows\System32\drivers\etc\hosts`, ligne `192.168.10.10 gitea.formini.local` (droits administrateur) ; à défaut, utilisez l'IP partout.

## Registre de conteneurs

Activé par défaut (`packages`). Il est servi en HTTP : chaque hôte Docker doit déclarer `gitea.formini.local:3000` comme `insecure-registries` (fait par `install-vm.sh`).

```bash
docker login gitea.formini.local:3000          # identifiant Gitea + mot de passe ou jeton
docker tag formini-tasks:dev gitea.formini.local:3000/equipe-a/formini-tasks:dev
docker push gitea.formini.local:3000/equipe-a/formini-tasks:dev
```

## Sauvegarde / remise à zéro

Toutes les données sont dans `./data`. Pour repartir de zéro : `docker compose down && sudo rm -rf data && docker compose up -d`, puis relancer `bootstrap.sh`.
