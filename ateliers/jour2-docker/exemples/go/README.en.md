# Go example — static binary, distroless image

_English version · la version française est dans [`README.md`](README.md)_

**What this example shows**: the ideal multi-stage case. We compile in `golang:1.23-alpine`
(≈ 250 MB) and keep only the binary in the final image, placed in a *distroless* base with no
shell and no package manager. Result: ≈ 8 MB and a minimal attack surface.

```bash
docker build -t formini-hello-go .
docker run --rm -p 8080:8080 formini-hello-go
curl -s localhost:8080/        # {"service":"formini-hello-go","message":"Bonjour Formini",...}
curl -s localhost:8080/health  # ok
docker images formini-hello-go
```

## Things to notice

- `COPY go.mod` then `go mod download` **before** `COPY . .`: dependencies stay cached as long
  as `go.mod` does not change. Edit `main.go` and rebuild: only the final compile layer runs again.
- `CGO_ENABLED=0` produces a binary with no libc dependency, so it runs in an empty image
  (`scratch`) or in distroless.
- `-ldflags="-s -w"` strips debug symbols (about 30 % smaller).
- The final image **has no shell**: `docker exec -it … sh` fails. That is intended. To debug,
  use `docker debug` or the `:debug` tag of distroless.
- No `HEALTHCHECK` in the Dockerfile: it would need `curl`, which is absent. The probe belongs
  to compose/Kubernetes (see Day 4, `readinessProbe`).

## Exercise

Replace the last stage with `FROM scratch` + `COPY --from=build /out/hello /hello`.
What happens if the program had to call an HTTPS API? (hint: CA certificates, `/etc/ssl/certs`).
Why is distroless the better compromise?
