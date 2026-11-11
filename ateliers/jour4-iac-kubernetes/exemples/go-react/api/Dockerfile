# API Formini (Go) — multi-stage, binaire statique, image distroless (~ 12 Mo).
FROM golang:1.23-alpine AS build
WORKDIR /src

# go.sum est généré ici si absent du dépôt (go mod tidy). Pour retrouver la mise en cache
# de la couche dépendances, lancez `go mod tidy` sur votre poste et committez go.sum.
COPY go.mod go.sum* ./
RUN go mod download || true

COPY . .
RUN go mod tidy && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /api
EXPOSE 8080
USER nonroot
ENTRYPOINT ["/api"]
