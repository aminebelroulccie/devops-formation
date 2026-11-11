# Pile Go — front React, API Go, PostgreSQL, Redis

_English version: [`README.en.md`](README.en.md)_

Un `compose.yaml` complet et autonome : un front **React** servi par nginx, une **API Go**
(Go 1.23 (pgx, go-redis), image distroless), une base **PostgreSQL** initialisée par un script SQL et un cache **Redis**.
Les trois autres piles ([`stack-go/`](../stack-go/), [`stack-python/`](../stack-python/),
[`stack-react-node/`](../stack-react-node/), [`stack-rust/`](../stack-rust/)) ont exactement la
même structure et le même contrat d'API : seul le dossier `api/` change.

```
  navigateur ──► frontend (nginx :8080) ──/api/──► api (Go :8080) ──┬──► db    (postgres 16)
                                                                        └──► cache (redis 7)
```

## Démarrer

```bash
cd ateliers/jour2-docker/exemples/stack-go
cp .env.example .env            # changez les deux mots de passe (PostgreSQL, Redis)
docker compose up -d --build    # première fois : 1 à 2 min
docker compose ps               # 4 services ; db et cache "healthy"
```

Ouvrez <http://localhost:8080>. L'API est aussi exposée sur 8081 pour `curl` :

```bash
curl -s localhost:8081/api/info
curl -s localhost:8081/api/tasks
curl -s -X POST localhost:8081/api/tasks -H 'Content-Type: application/json' -d '{"title":"via curl"}'
curl -s localhost:8081/api/hits
```

## Le contrat de l'API

| Méthode | Route | Réponse |
|---------|-------|---------|
| GET | `/health` | `ok` (texte), utilisé par le HEALTHCHECK |
| GET | `/api/info` | `{service, language, hostname, postgres, redis}` |
| GET | `/api/tasks` | 50 dernières tâches |
| POST | `/api/tasks` | `{"title": "…"}` → 201 et la tâche créée |
| GET | `/api/hits` | incrémente la clé Redis `hits:api-go` et renvoie `{service, hits}` |

## Ce qu'il faut observer

1. **Découverte de services** : l'API joint la base par son nom `db` et le cache par `cache`
   (`DATABASE_URL`, `REDIS_URL` dans `compose.yaml` ; Redis exige un mot de passe, `--requirepass`) ; nginx joint l'API par son nom `api`
   (`frontend/nginx.conf`). Aucune IP codée en dur.
2. **Ordre de démarrage** : `depends_on … condition: service_healthy`. L'API ne démarre qu'une
   fois `pg_isready` et `redis-cli ping` passés. Commentez ces lignes et relancez pour voir la
   différence (puis `restart: unless-stopped` rattrape le coup).
3. **Initialisation de la base** : `db/init.sql` monté dans `docker-entrypoint-initdb.d`, exécuté
   uniquement à la création du volume. `docker compose down -v` pour rejouer.
4. **Image de l'API** : `docker images formini-go-api` ≈ 12 Mo. Comparez avec les autres piles.
5. **Données persistantes** : `down` puis `up`, tâches et compteur sont toujours là ; `down -v`
   les efface.

## Exercices

- **Réplication.** Retirez le bloc `ports` du service `api`, puis
  `docker compose up -d --scale api=3`. Rafraîchissez la page : le champ *Conteneur* change,
  nginx répartit les requêtes sur les trois réplicas.
- **Panne contrôlée.** `docker compose stop cache`. Que renvoient `/api/info` et `/api/tasks` ?
  Puis `docker compose start cache`.
- **Un seul port exposé.** Supprimez le `ports` de `api`. Tout fonctionne-t-il encore ? Pourquoi
  est-ce la configuration de production ?
- **Publier.** Poussez les deux images dans le registre Gitea
  (`gitea.formini.local:3000/equipe-a/formini-go-api:0.1.0`), puis remplacez `build:` par
  `image:` dans un `compose.prod.yaml`.

## Arrêter

```bash
docker compose down        # conserve les données
docker compose down -v     # efface aussi les volumes
```
