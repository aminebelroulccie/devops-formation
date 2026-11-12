// Tests du front (Vitest + Testing Library) : l'API est simulée, aucun service à lancer.
//   npm test            (une fois)      npm run test:watch   (en continu)
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import App from './App.jsx'

const info = { service: 'api-test', language: 'Test 1.0', hostname: 'pod-abc12', postgres: 'ok', redis: 'ok' }
const tasks = [{ id: 1, title: 'Écrire le Dockerfile', done: false, created_by: 'init' }]

// fetch simulé : une réponse par "MÉTHODE url" ; 404 pour tout le reste
function mockFetch(routes) {
  return vi.fn(async (url, options = {}) => {
    const handler = routes[`${options.method ?? 'GET'} ${url}`]
    if (!handler) return { ok: false, status: 404, statusText: 'Not Found', json: async () => ({ error: 'route inconnue' }) }
    const body = typeof handler === 'function' ? handler(options) : handler
    return { ok: true, status: 200, json: async () => body }
  })
}

beforeEach(() => vi.restoreAllMocks())

describe('Front Formini', () => {
  it('affiche le service, son état et les tâches', async () => {
    global.fetch = mockFetch({ 'GET /api/info': info, 'GET /api/tasks': tasks })
    render(<App />)
    expect(await screen.findByText('api-test')).toBeInTheDocument()
    expect(screen.getByText('pod-abc12')).toBeInTheDocument()
    expect(screen.getByText(/Écrire le Dockerfile/)).toBeInTheDocument()
    expect(screen.getAllByText('ok')).toHaveLength(2)           // PostgreSQL et Redis
    expect(global.fetch).toHaveBeenCalledWith('/api/info', undefined)
  })

  it('crée une tâche puis recharge la liste', async () => {
    const created = []
    global.fetch = mockFetch({
      'GET /api/info': info,
      'GET /api/tasks': () => [...created, ...tasks],
      'POST /api/tasks': (o) => {
        const t = { id: 2, title: JSON.parse(o.body).title, done: false, created_by: 'api-test' }
        created.unshift(t)
        return t
      },
    })
    render(<App />)
    await screen.findByText('api-test')
    await userEvent.type(screen.getByPlaceholderText('Nouvelle tâche'), 'Tester le front')
    await userEvent.click(screen.getByRole('button', { name: 'Ajouter' }))
    expect(await screen.findByText(/Tester le front/)).toBeInTheDocument()
    expect(global.fetch).toHaveBeenCalledWith('/api/tasks', expect.objectContaining({ method: 'POST' }))
    expect(screen.getByPlaceholderText('Nouvelle tâche')).toHaveValue('')   // champ vidé après envoi
  })

  it('incrémente le compteur Redis', async () => {
    global.fetch = mockFetch({ 'GET /api/info': info, 'GET /api/tasks': [], 'GET /api/hits': { service: 'api-test', hits: 7 } })
    render(<App />)
    await screen.findByText('api-test')
    expect(screen.getByText('Aucune tâche.')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Incrémenter' }))
    expect(await screen.findByText('7')).toBeInTheDocument()
  })

  it("affiche une erreur claire quand l'API est injoignable", async () => {
    global.fetch = vi.fn(async () => ({ ok: false, status: 502, statusText: 'Bad Gateway', json: async () => { throw new Error('pas du JSON') } }))
    render(<App />)
    expect(await screen.findByText(/API injoignable/)).toBeInTheDocument()
    expect(screen.getByText(/502 Bad Gateway/)).toBeInTheDocument()
    expect(screen.queryByText('Aucune tâche.')).not.toBeInTheDocument()
  })
})
