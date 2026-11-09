# Formini Hello (Rust) — multi-stage avec mise en cache des dépendances compilées.
# Rust compile lentement : l'astuce du "main.rs factice" permet de ne recompiler
# les crates tierces que si Cargo.toml / Cargo.lock changent.
# Taille attendue de l'image finale : ~ 25 Mo (binaire ≈ 1 Mo + debian-slim).

# ---- étape 1 : build -------------------------------------------------------
FROM rust:1.83-slim AS build
WORKDIR /src

# 1. manifeste + main.rs vide → compile uniquement les dépendances (couche en cache)
COPY Cargo.toml Cargo.lock* ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
 && cargo build --release \
 && rm -rf src

# 2. vrai code : seule l'application est recompilée
COPY src ./src
# touch : force cargo à voir main.rs comme modifié par rapport au factice
RUN touch src/main.rs && cargo build --release

# ---- étape 2 : image finale -------------------------------------------------
# debian-slim (et non scratch) : le binaire est lié dynamiquement à la glibc
FROM debian:bookworm-slim
RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin app
COPY --from=build /src/target/release/formini-hello-rust /usr/local/bin/hello
USER app
EXPOSE 8080
# pas de curl dans slim ; la sonde se fait côté orchestrateur (ou ajoutez curl, +4 Mo)
ENTRYPOINT ["/usr/local/bin/hello"]
