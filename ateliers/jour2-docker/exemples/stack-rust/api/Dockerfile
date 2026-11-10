# API Formini (Rust) — multi-stage avec cache des dépendances compilées (~ 30 Mo).
# Première construction : 5 à 10 minutes (postgres, redis, serde). Ensuite, quelques secondes.
FROM rust:1.83-slim AS build
WORKDIR /src

# 1. dépendances seules, avec un main.rs factice → couche en cache
COPY Cargo.toml Cargo.lock* ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
 && cargo build --release \
 && rm -rf src

# 2. vrai code
COPY src ./src
RUN touch src/main.rs && RUSTC_VERSION="$(rustc --version | cut -d' ' -f2)" cargo build --release

FROM debian:bookworm-slim
RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin app
COPY --from=build /src/target/release/api-rust /usr/local/bin/api
USER app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/api"]
