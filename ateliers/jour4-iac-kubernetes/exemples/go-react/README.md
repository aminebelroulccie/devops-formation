# Kubernetes — pile Go + React complète (namespace `formini-go`)

_English version: [`README.en.md`](README.en.md)_

La pile du jour 2 ([`stack-go/`](../../../jour2-docker/exemples/stack-go/README.md)) et du jour 3
([`jour3-cicd/exemples/go/`](../../../jour3-cicd/exemples/go/README.md)), cette fois sur
Kubernetes. Tout ce qu'il faut est dans `k8s/` : le namespace, le Secret, les deux bases en
**StatefulSet**, l'API et le front en Deployment, les Services, et un ConfigMap pour le schéma SQL.

```
  navigateur ──► Service frontend (NodePort 30081 → localhost:8081)
                        │
                 Deployment frontend ×2  (nginx : /api/ → http://api:8080/)
                        │
                 Service api (ClusterIP)
                        │
                 Deployment api ×2  (Go)
                   │            │
       Service postgres     Service cache        ← headless (clusterIP: None)
       (headless)           (headless)
          │                    │
     StatefulSet postgres   StatefulSet cache
     pod postgres-0         pod cache-0
     PVC data-postgres-0    PVC data-cache-0
```

| Fichier | Objets | Pourquoi ce type |
|---------|--------|------------------|
| `namespace.yaml` | Namespace `formini-go` | un espace isolé par application : noms, quotas, RBAC |
| `secret.example.yaml` | Secret `go-secret` | les mots de passe PostgreSQL et Redis, jamais en clair dans un manifeste |
| `postgres.yaml` | Service headless + **StatefulSet** `postgres` | une base a un état : nom stable `postgres-0`, **son** PVC `data-postgres-0` |
| `redis.yaml` | Service headless + **StatefulSet** `cache` | Redis persiste ici (`--save`) et exige un mot de passe (`--requirepass`) : même règle que PostgreSQL |
| `api.yaml` | **Deployment** `api` ×2 + Service ClusterIP `api` | sans état : répliques interchangeables, rolling update ; initContainers qui attendent PostgreSQL et Redis |
| `frontend.yaml` | **Deployment** `frontend` ×2 + Service NodePort `frontend` | sans état ; seul point exposé hors du cluster ; initContainer qui attend l'API |
| `configmap-api.yaml` | ConfigMap `api-config` | hôtes, ports, noms pour l'API : **toute sa configuration non secrète** |
| `configmap-postgres.yaml` | ConfigMaps `postgres-config`, `postgres-init` | variables PostgreSQL et le schéma `init.sql` |
| `configmap-redis.yaml` | ConfigMap `redis-config` | le fichier `redis.conf` monté dans le pod |
| `configmap-frontend.yaml` | ConfigMap `frontend-config` | `nginx.conf` et `proxy-params.conf`, montés par-dessus ceux de l'image |
| `kustomization.yaml` | la liste des manifestes | `kubectl apply -k k8s/` en une commande |
| `kind-config.yaml` | cluster kind avec les ports 30080 et 30081 | utile si vous recréez le cluster |

## Le code

Ce dossier est un dépôt complet, le même que [`jour3-cicd/exemples/go/`](../../../jour3-cicd/exemples/go/README.md)
plus `k8s/` :

```
api/            l'API Go (pgx, go-redis) et ses tests · Dockerfile distroless
frontend/       le front React (Vite) servi par nginx, proxy /api/ → api:8080
db/init.sql     schéma PostgreSQL (le même contenu que le ConfigMap postgres-init)
compose.yaml    la pile en local : cp .env.example .env && docker compose up -d --build → http://localhost:8080
.gitea/         pipeline CI/CD du jour 3 : lint, tests, intégration, scan, publication, release
k8s/            les manifestes Kubernetes décrits ci-dessous
```

Contrat de l'API : `GET /health`, `GET /api/info`, `GET`/`POST /api/tasks`, `GET /api/hits`.
Redis et PostgreSQL exigent un mot de passe : en local via `.env`, sur Kubernetes via le Secret `go-secret`.

## Prérequis

- Les images `formini-go-api:v1.0.0` et `formini-go-frontend:v1.0.0` publiées dans le registre
  Gitea de votre organisation (pipeline du jour 3 : `git tag v1.0.0`). Adaptez `equipe-a` dans
  `api.yaml` et `frontend.yaml`.
- Un cluster kind `formini` dont les nœuds acceptent le registre Gitea en HTTP (fait par
  `solution/deploy.sh` ou `solution/deploy.sh --kind-only`). Pour joindre le front sur
  `localhost:8081`, le cluster doit avoir été créé avec `k8s/kind-config.yaml` de ce dossier
  (port 30081) ; sinon utilisez `kubectl port-forward` (plus bas).

## Déployer

```bash
cd ateliers/jour4-iac-kubernetes/exemples/go-react
cp k8s/secret.example.yaml k8s/secret.yaml   # puis changez les deux mots de passe (PostgreSQL, Redis)
bash apply.sh                               # ou : kubectl apply -k k8s/
kubectl -n formini-go get all,pvc
```

```
NAME                            READY   STATUS    RESTARTS   AGE
pod/api-7c9d4f8b6-abcde         1/1     Running   0          60s
pod/api-7c9d4f8b6-fghij         1/1     Running   0          60s
pod/cache-0                     1/1     Running   0          60s
pod/frontend-5f6c7d8e9-klmno    1/1     Running   0          60s
pod/frontend-5f6c7d8e9-pqrst    1/1     Running   0          60s
pod/postgres-0                  1/1     Running   0          60s
…
NAME                                     STATUS   VOLUME     CAPACITY   ACCESS MODES
persistentvolumeclaim/data-cache-0       Bound    pvc-…      256Mi      RWO
persistentvolumeclaim/data-postgres-0    Bound    pvc-…      1Gi        RWO
```

Ouvrez <http://localhost:8081> (ou `kubectl -n formini-go port-forward svc/frontend 8081:80`
puis la même adresse). Créez une tâche, incrémentez le compteur.

## Ce qu'il faut observer

1. **Deux familles d'objets.** `api` et `frontend` sont des Deployments : pods aux noms aléatoires,
   remplaçables. `postgres` et `cache` sont des StatefulSets : pods `postgres-0`, `cache-0`, chacun
   avec son PVC. `kubectl get pvc` montre les noms `data-<statefulset>-0`.
2. **Les noms DNS sont ceux de Compose.** `postgres`, `cache`, `api` : les mêmes `DATABASE_URL`,
   `REDIS_URL` et `proxy_pass` qu'au jour 2, sans changer une ligne de code ni de config nginx.
3. **Configuration = ConfigMap, secret = Secret.** Les workloads ne contiennent aucune valeur de
   configuration : l'API lit `api-config` (`envFrom` + `$(VAR)` pour assembler `DATABASE_URL` et
   `REDIS_URL`), PostgreSQL lit `postgres-config`, Redis monte `redis.conf` depuis `redis-config`,
   nginx monte `nginx.conf` depuis `frontend-config` (qui **remplace** celle de l'image), et le
   schéma `init.sql` est monté dans `/docker-entrypoint-initdb.d`. Seuls les mots de passe sont
   dans le Secret `go-secret`.
4. **Le front est le seul point d'entrée.** Un seul NodePort ; l'API, Redis et PostgreSQL ne sont
   joignables que dans le cluster.
5. **Démarrage dans le bon ordre : les initContainers.** Kubernetes n'a pas de `depends_on` ;
   on le reconstruit avec des `initContainers` qui bouclent jusqu'à ce que le service attendu
   réponde : `api` attend `pg_isready` sur `postgres` et un `PONG` de `cache`, `frontend` attend
   `/health` de `api`. Regardez-les : `kubectl -n formini-go get pods -w` montre `Init:0/2` puis
   `Init:1/2` sur les pods `api`, et `kubectl logs <pod> -c wait-for-postgres` leur journal.
   `postgres` et `cache` n'attendent rien : ils n'ont pas de dépendance amont. Même sans ces
   initContainers l'application finirait par converger grâce aux `readinessProbe`, mais avec
   des redémarrages et des erreurs dans les journaux.

## Exercices

- **Identité stable.** `kubectl -n formini-go delete pod postgres-0` : le pod revient avec le même
  nom, remonte `data-postgres-0`, les tâches sont toujours là. Comparez avec
  `kubectl -n formini-go delete pod -l app=api` : nouveaux noms, aucune donnée perdue non plus,
  mais pour une autre raison. Laquelle ?
- **Supprimer sans perdre.** `kubectl -n formini-go delete statefulset postgres`, puis
  `kubectl -n formini-go get pvc` : le PVC est toujours là. Réappliquez (`kubectl apply -k k8s/`) :
  les données reviennent. Effacez-les volontairement avec `kubectl -n formini-go delete pvc data-postgres-0`.
- **Redis volatil.** Transformez `cache` en Deployment avec un volume `emptyDir` (retirez
  `--save`). Que devient le compteur après `kubectl delete pod -l app=cache` ? Quand est-ce
  acceptable ?
- **Changer la configuration sans reconstruire.** Dans `k8s/configmap-frontend.yaml`, passez
  `proxy_read_timeout` à `2s` ; `kubectl apply -k k8s/` puis
  `kubectl -n formini-go rollout restart deployment/frontend`. Même chose avec `loglevel verbose`
  dans `redis-config` puis `rollout restart statefulset/cache`. Pourquoi faut-il le `rollout restart` ?
  (indice : un ConfigMap monté en `subPath` ou lu par `envFrom` n'est pas rechargé à chaud).
- **Dépendances.** `kubectl -n formini-go scale statefulset/postgres --replicas=0`, puis
  `kubectl -n formini-go rollout restart deployment/api` : les nouveaux pods `api` restent en
  `Init:0/2`, l'ancienne version continue de servir (rolling update + `maxUnavailable: 0`).
  Remettez `--replicas=1` : les init containers se terminent, le déploiement se poursuit.
- **Rolling update.** `kubectl -n formini-go set image deployment/api api=…/formini-go-api:v1.1.0`
  avec une boucle `curl` sur `localhost:8081/api/health` : zéro erreur. Puis
  `kubectl -n formini-go rollout undo deployment/api`.
- **Échelle.** `kubectl -n formini-go scale deployment/api --replicas=4`, rafraîchissez la page :
  le champ *Conteneur* change. Essayez `scale statefulset/postgres --replicas=2` : pourquoi est-ce
  une mauvaise idée telle quelle ? (indice : deux PostgreSQL indépendants, pas une réplication).

## Nettoyer

```bash
kubectl delete namespace formini-go     # supprime tout, PVC compris
```
