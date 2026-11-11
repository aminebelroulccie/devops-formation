# API Formini (Node / Express) — multi-stage : dépendances de production seules,
# utilisateur `node` fourni par l'image, init léger pour les signaux (~ 140 Mo).
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json server.js ./
USER node
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health >/dev/null || exit 1
# node n'est pas un bon PID 1 (zombies, signaux) : l'image fournit un init minimal via --init
# côté docker run, ou on garde la forme exec et on gère SIGTERM dans le code (fait ici).
CMD ["node", "server.js"]
