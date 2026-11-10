import { useCallback, useEffect, useState } from 'react'

// L'API (Python) est jointe via nginx : /api/… → http://api:8080/api/…
async function api(path, options) {
  const res = await fetch(`/api${path}`, options)
  if (!res.ok) {
    let detail = `${res.status} ${res.statusText}`
    try { detail = (await res.json()).error ?? detail } catch { /* corps non JSON */ }
    throw new Error(detail)
  }
  return res.json()
}

export default function App() {
  const [info, setInfo] = useState(null)
  const [tasks, setTasks] = useState([])
  const [hits, setHits] = useState(null)
  const [title, setTitle] = useState('')
  const [error, setError] = useState('')

  const refresh = useCallback(async () => {
    setError('')
    try {
      const [i, t] = await Promise.all([api('/info'), api('/tasks')])
      setInfo(i)
      setTasks(t)
    } catch (e) {
      setError(`API injoignable : ${e.message}`)
      setInfo(null)
      setTasks([])
    }
  }, [])

  useEffect(() => { refresh() }, [refresh])

  async function addTask(ev) {
    ev.preventDefault()
    if (!title.trim()) return
    try {
      await api('/tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title }),
      })
      setTitle('')
      refresh()
    } catch (e) { setError(e.message) }
  }

  async function hit() {
    try { setHits((await api('/hits')).hits) } catch (e) { setError(e.message) }
  }

  const status = (v) => (v === 'ok' ? <span className="ok">ok</span> : <span className="err">{v ?? '—'}</span>)

  return (
    <>
      <header>
        <p className="eyebrow">Formini · Jour 2 · Docker Compose</p>
        <h1>Front React · API Python · PostgreSQL · Redis</h1>
      </header>
      <main>
        <div className="tabs">
          <button className="ghost" onClick={refresh}>Rafraîchir</button>
        </div>

        {error && <p className="error">{error}</p>}

        <div className="grid">
          <section className="card">
            <h2>Service</h2>
            <dl>
              <dt>Nom</dt><dd>{info?.service ?? '—'}</dd>
              <dt>Langage</dt><dd>{info?.language ?? '—'}</dd>
              <dt>Conteneur</dt><dd><code>{info?.hostname ?? '—'}</code></dd>
              <dt>PostgreSQL</dt><dd>{status(info?.postgres)}</dd>
              <dt>Redis</dt><dd>{status(info?.redis)}</dd>
            </dl>
          </section>

          <section className="card">
            <h2>Compteur Redis (clé hits:{info?.service ?? 'api'})</h2>
            <div className="hits">{hits ?? '·'}</div>
            <button className="primary" onClick={hit}>Incrémenter</button>
            <p style={{ fontSize: 13, color: 'var(--muted)' }}>
              Le compteur vit dans Redis : il survit au redémarrage de l'API (volume <code>redisdata</code>).
            </p>
          </section>
        </div>

        <section className="card" style={{ marginTop: 16 }}>
          <h2>Tâches (table PostgreSQL)</h2>
          <form onSubmit={addTask}>
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Nouvelle tâche" maxLength={200} />
            <button className="primary" type="submit">Ajouter</button>
          </form>
          <ul className="tasks">
            {tasks.map((t) => (
              <li key={t.id}>
                <span>#{t.id} · {t.title}</span>
                <span className="tag">{t.created_by}</span>
              </li>
            ))}
            {tasks.length === 0 && !error && <li style={{ color: 'var(--muted)' }}>Aucune tâche.</li>}
          </ul>
        </section>

        <footer>
          Quatre conteneurs, un réseau : le front joint l'API par son nom <code>api</code>, l'API joint
          <code> db</code> et <code>cache</code>. Le champ <em>Conteneur</em> change si vous répliquez l'API.
        </footer>
      </main>
    </>
  )
}
