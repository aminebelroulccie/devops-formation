# Formini Hello (Go) — multi-stage : compilation dans une image complète,
# exécution dans une image "distroless" qui ne contient que le binaire.
# Taille attendue de l'image finale : ~ 8 Mo.

# ---- étape 1 : build -------------------------------------------------------
FROM golang:1.23-alpine AS build
WORKDIR /src

# 1. dépendances d'abord : couche mise en cache tant que go.mod/go.sum ne changent pas
COPY go.mod ./
RUN go mod download

# 2. code, puis compilation d'un binaire statique (pas de libc nécessaire)
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/hello .

# ---- étape 2 : image finale -------------------------------------------------
# distroless/static : pas de shell, pas de gestionnaire de paquets, utilisateur non-root (65532)
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/hello /hello
EXPOSE 8080
USER nonroot
# Pas de HEALTHCHECK ici : l'image n'a ni curl ni shell. En production, c'est
# l'orchestrateur (compose / Kubernetes) qui sonde GET /health.
ENTRYPOINT ["/hello"]
