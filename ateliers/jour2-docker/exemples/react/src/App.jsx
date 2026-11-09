import { useEffect, useState } from 'react'

// Petite page statique : affiche un message et interroge /health (servi par nginx).
export default function App() {
  const [health, setHealth] = useState('…')

  useEffect(() => {
    fetch('/health')
      .then((r) => (r.ok ? 'ok' : `erreur ${r.status}`))
      .catch(() => 'injoignable')
      .then(setHealth)
  }, [])

  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', maxWidth: 560, margin: '4rem auto', padding: '0 1rem' }}>
      <p style={{ letterSpacing: '.15em', textTransform: 'uppercase', fontSize: 12, color: '#C9A227' }}>Formini · Jour 2</p>
      <h1 style={{ color: '#0B2545' }}>Bonjour Formini</h1>
      <p>
        Cette page est une application <strong>React</strong> compilée par Vite, puis servie
        par <strong>nginx</strong> dans un conteneur de quelques dizaines de mégaoctets.
      </p>
      <p>
        État de <code>/health</code> : <strong>{health}</strong>
      </p>
    </main>
  )
}
