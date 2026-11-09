# Exemple React — construit avec Node, servi par nginx

_English version: [`README.en.md`](README.en.md)_

**Ce que montre cet exemple** : pour un front-end, l'outil de build (Node, npm, `node_modules`,
souvent > 500 Mo) n'a rien à faire en production. On compile dans `node:22-alpine`, puis on
copie uniquement le dossier `dist/` dans un **nginx non privilégié**. L'image finale fait
≈ 50 Mo et ne contient aucun code JavaScript côté serveur.

```bash
docker build -t formini-hello-react .
docker run --rm -p 8080:8080 formini-hello-react
open http://localhost:8080/       # la page affiche « Bonjour Formini » et l'état de /health
curl -s localhost:8080/health     # ok
docker images formini-hello-react
```

> Première construction : `npm ci` exige un `package-lock.json`. S'il manque, lancez
> `npm install` une fois sur votre poste (il le génère) et committez-le. C'est ce fichier qui
> rend le build reproductible.

## Points à observer

- `COPY package.json package-lock.json*` puis `npm ci` **avant** `COPY . .` : le
  téléchargement des paquets est en cache tant que le lock ne change pas.
- `nginxinc/nginx-unprivileged` tourne avec l'utilisateur 101 et écoute sur **8080**, pas 80 :
  un processus non root ne peut pas ouvrir un port < 1024 sans capacité spéciale.
- `nginx.conf` : repli `try_files … /index.html` pour le routage côté client, cache immuable
  sur `/assets/` (noms fingerprintés par Vite), route `/health` servie sans accès disque.
- Le `HEALTHCHECK` utilise `wget`, présent dans Alpine (`curl` ne l'est pas).

## Exercice

Ajoutez une variable d'environnement d'URL d'API lue **au moment du build** (`VITE_API_URL`)
avec `ARG` + `ENV` dans l'étape 1. Pourquoi une variable passée à `docker run -e` ne suffit-elle
pas pour une application compilée en statique ? Quelle solution pour la rendre configurable au
démarrage (indice : fichier `config.json` généré par un script d'entrée) ?
