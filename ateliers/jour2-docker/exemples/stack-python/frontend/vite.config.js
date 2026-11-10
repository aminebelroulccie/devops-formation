import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// En développement local (npm run dev), /api est relayé vers l'API exposée par compose sur 8081.
// En production, c'est nginx qui joue ce rôle (nginx.conf).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    proxy: { '/api': 'http://localhost:8081' },
  },
})
