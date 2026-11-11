// Tests unitaires (node:test, inclus dans Node) sans base ni cache.
import { test } from 'node:test'
import assert from 'node:assert/strict'

process.env.DATABASE_URL ||= 'postgresql://x:x@localhost:5432/x'
const { default: app } = await import('../server.js')

// un serveur éphémère sur un port libre, fermé après chaque test
async function withServer(fn) {
  const server = app.listen(0)
  const base = `http://127.0.0.1:${server.address().port}`
  try { await fn(base) } finally { server.close() }
}

test('GET /health répond ok', () => withServer(async (base) => {
  const res = await fetch(`${base}/health`)
  assert.equal(res.status, 200)
  assert.equal(await res.text(), 'ok')
}))

test('POST /api/tasks sans titre → 400', () => withServer(async (base) => {
  const res = await fetch(`${base}/api/tasks`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ title: '  ' }),
  })
  assert.equal(res.status, 400)
  assert.deepEqual(await res.json(), { error: 'title requis' })
}))
