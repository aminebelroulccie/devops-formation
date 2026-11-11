// API Formini (Node / Express) — même contrat que les API Go, Python et Rust.
//   GET  /health      → "ok"
//   GET  /api/info    → identité du service + état de PostgreSQL et Redis
//   GET  /api/tasks   → liste des tâches (table partagée)
//   POST /api/tasks   → {"title": "..."} crée une tâche
//   GET  /api/hits    → incrémente et renvoie le compteur Redis de ce service
import os from 'node:os'
import { pathToFileURL } from 'node:url'
import express from 'express'
import pg from 'pg'
import Redis from 'ioredis'

const SERVICE = 'api-node'
const PORT = process.env.PORT || 8080

const db = new pg.Pool({ connectionString: process.env.DATABASE_URL, connectionTimeoutMillis: 2000 })
const cache = new Redis(process.env.REDIS_URL || 'redis://cache:6379/0', { lazyConnect: true, maxRetriesPerRequest: 1 })
cache.on('error', (err) => console.error('redis :', err.message))

const app = express()
app.use(express.json())
app.use((req, res, next) => {
  const start = Date.now()
  res.on('finish', () => console.log(`${req.method} ${req.path} ${res.statusCode} ${Date.now() - start}ms`))
  next()
})

app.get('/health', (_req, res) => res.type('text').send('ok'))

app.get('/api/info', async (_req, res) => {
  let postgres = 'ok'
  let redis = 'ok'
  try { await db.query('SELECT 1') } catch (e) { postgres = `erreur : ${e.message}` }
  try { await cache.ping() } catch (e) { redis = `erreur : ${e.message}` }
  res.json({ service: SERVICE, language: `Node ${process.versions.node}`, hostname: os.hostname(), postgres, redis })
})

app.get('/api/tasks', async (_req, res, next) => {
  try {
    const { rows } = await db.query(
      'SELECT id, title, done, created_by, created_at FROM tasks ORDER BY id DESC LIMIT 50')
    res.json(rows)
  } catch (e) { next(e) }
})

app.post('/api/tasks', async (req, res, next) => {
  const title = String(req.body?.title ?? '').trim()
  if (!title) return res.status(400).json({ error: 'title requis' })
  try {
    const { rows } = await db.query(
      'INSERT INTO tasks (title, created_by) VALUES ($1, $2) RETURNING id, title, done, created_by, created_at',
      [title, SERVICE])
    res.status(201).json(rows[0])
  } catch (e) { next(e) }
})

app.get('/api/hits', async (_req, res, next) => {
  try {
    const hits = await cache.incr(`hits:${SERVICE}`)
    res.json({ service: SERVICE, hits })
  } catch (e) { next(e) }
})

// gestionnaire d'erreurs : une réponse JSON, jamais une pile d'appels HTML
app.use((err, _req, res, _next) => {
  console.error('erreur :', err.message)
  res.status(500).json({ error: err.message })
})

export default app

// Démarrage du serveur uniquement quand le fichier est exécuté directement
// (node server.js) ; les tests importent `app` sans ouvrir de port.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const server = app.listen(PORT, () => console.log(`${SERVICE} en écoute sur :${PORT}`))

  // arrêt propre sur SIGTERM (docker stop) : on ferme les connexions avant de quitter
  process.on('SIGTERM', async () => {
    server.close()
    await Promise.allSettled([db.end(), cache.quit()])
    process.exit(0)
  })
}
