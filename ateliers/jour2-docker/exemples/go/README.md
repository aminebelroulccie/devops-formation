# Exemple Go — binaire statique, image distroless

_English version: [`README.en.md`](README.en.md)_

**Ce que montre cet exemple** : le cas idéal du multi-stage. On compile dans `golang:1.23-alpine`
(≈ 250 Mo) et on ne garde dans l'image finale que le binaire, posé dans une image
*distroless* sans shell ni gestionnaire de paquets. Résultat : ≈ 8 Mo, surface d'attaque minimale.

```bash
docker build -t formini-hello-go .
docker run --rm -p 8080:8080 formini-hello-go
curl -s localhost:8080/        # {"service":"formini-hello-go","message":"Bonjour Formini",...}
curl -s localhost:8080/health  # ok
docker images formini-hello-go
```

## Points à observer

- `COPY go.mod` puis `go mod download` **avant** `COPY . .` : les dépendances sont en cache
  tant que `go.mod` ne change pas. Changez `main.go` et relancez le build : seule la
  dernière couche de compilation est refaite.
- `CGO_ENABLED=0` produit un binaire sans dépendance à la libc : il tourne dans une image
  vide (`scratch`) ou distroless.
- `-ldflags="-s -w"` retire les symboles de débogage (≈ 30 % de taille en moins).
- L'image finale **n'a pas de shell** : `docker exec -it … sh` échoue. C'est voulu. Pour
  déboguer, utilisez `docker debug` ou une image `:debug` de distroless.
- Pas de `HEALTHCHECK` dans le Dockerfile : il faudrait `curl`, absent. La sonde se fait
  côté compose/Kubernetes (voir jour 4, `readinessProbe`).

## Exercice

Remplacez la dernière étape par `FROM scratch` + `COPY --from=build /out/hello /hello`.
Que se passe-t-il si le programme devait appeler une API en HTTPS ? (indice : certificats CA,
`/etc/ssl/certs`). Pourquoi distroless est-il un meilleur compromis ?
