# Rust example — caching compiled dependencies

_English version · la version française est dans [`README.md`](README.md)_

**What this example shows**: when compilation is slow (Rust, C++, Scala…), layer order becomes
critical. We first compile the dependencies with a dummy `main.rs`, and only then the
application code. Editing `main.rs` now recompiles only the application: a few seconds instead
of several minutes.

```bash
docker build -t formini-hello-rust .          # first time: 2 to 5 minutes (downloads and compiles tiny_http)
docker run --rm -p 8080:8080 formini-hello-rust
curl -s localhost:8080/        # {"service":"formini-hello-rust","message":"Bonjour Formini",...}
curl -s localhost:8080/health  # ok
docker images formini-hello-rust
```

Then change the message in `src/main.rs` and run `docker build` again: the dependency
`cargo build` step is reported as `CACHED`.

## Things to notice

- `COPY Cargo.toml Cargo.lock*` + empty `main.rs` + `cargo build --release`: the crates are
  compiled in a layer that does not depend on your code.
- `touch src/main.rs`: without it, cargo may consider the dummy binary up to date (same
  timestamp) and skip recompiling.
- `strip = true`, `lto = true` in `Cargo.toml`: binary ≈ 1 MB instead of ≈ 5 MB.
- The final image is `debian:bookworm-slim`, not `scratch`: the binary links against glibc.
  For `scratch` you would compile for the `x86_64-unknown-linux-musl` target.
- As with Go, no `HEALTHCHECK`: `curl` is not in slim.

## Exercise

Replace the last stage with `gcr.io/distroless/cc-debian12:nonroot` (glibc and nothing else).
Compare size and CVE count with `trivy image` between `debian-slim` and `distroless/cc`.
