# Formini Hello (React / Vite) — multi-stage : Node ne sert qu'à construire,
# l'image finale est un nginx non privilégié avec les fichiers statiques.
# Taille attendue : ~ 50 Mo (contre > 1 Go si on livrait node_modules).

# ---- étape 1 : build -------------------------------------------------------
FROM node:22-alpine AS build
WORKDIR /src

# 1. dépendances : npm ci est reproductible et respecte package-lock.json
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund

# 2. sources, puis compilation vers /src/dist
COPY . .
RUN npm run build

# ---- étape 2 : image finale -------------------------------------------------
# nginx-unprivileged : tourne en utilisateur 101, écoute sur 8080 (pas besoin de root pour < 1024)
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health >/dev/null || exit 1
# CMD hérité de l'image : nginx -g "daemon off;"
