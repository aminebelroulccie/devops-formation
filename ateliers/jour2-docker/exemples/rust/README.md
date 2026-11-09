# Exemple Rust — cache des dépendances compilées

_English version: [`README.en.md`](README.en.md)_

**Ce que montre cet exemple** : quand la compilation est longue (Rust, C++, Scala…), l'ordre
des couches devient crucial. On compile d'abord les dépendances avec un `main.rs` factice, puis
seulement le code de l'application. Modifier `main.rs` ne recompile plus que l'application :
quelques secondes au lieu de plusieurs minutes.

```bash
docker build -t formini-hello-rust .          # première fois : 2 à 5 minutes (télécharge et compile tiny_http)
docker run --rm -p 8080:8080 formini-hello-rust
curl -s localhost:8080/        # {"service":"formini-hello-rust","message":"Bonjour Formini",...}
curl -s localhost:8080/health  # ok
docker images formini-hello-rust
```

Puis modifiez le message dans `src/main.rs` et relancez `docker build` : observez que l'étape
`cargo build` des dépendances est marquée `CACHED`.

## Points à observer

- `COPY Cargo.toml Cargo.lock*` + `main.rs` vide + `cargo build --release` : les crates sont
  compilées dans une couche qui ne dépend pas de votre code.
- `touch src/main.rs` : sans cela, cargo peut considérer le binaire factice comme à jour (même
  horodatage) et ne pas recompiler.
- `strip = true`, `lto = true` dans `Cargo.toml` : binaire ≈ 1 Mo au lieu de ≈ 5 Mo.
- L'image finale est `debian:bookworm-slim`, pas `scratch` : le binaire est lié à la glibc. Pour
  `scratch`, il faudrait compiler avec la cible `x86_64-unknown-linux-musl`.
- Comme pour Go, pas de `HEALTHCHECK` : `curl` est absent de slim.

## Exercice

Remplacez la dernière étape par `gcr.io/distroless/cc-debian12:nonroot` (contient la glibc et
rien d'autre). Comparez la taille et le nombre de CVE avec `trivy image` entre `debian-slim` et
`distroless/cc`.
