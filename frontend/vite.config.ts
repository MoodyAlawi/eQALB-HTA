import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

// Every economic number comes from the R model, reached through the FastAPI
// service in ../api (api/run_api.py, 127.0.0.1:8788). Proxying /api keeps the
// browser on a single origin in development, so no CORS handling is needed
// here. Point EQALB_API_URL elsewhere if the API runs on another port.
const apiTarget = process.env.EQALB_API_URL ?? 'http://127.0.0.1:8788'

export default defineConfig({
  plugins: [vue()],
  server: {
    host: '127.0.0.1',
    port: 5173,
    proxy: {
      '/api': { target: apiTarget, changeOrigin: true },
    },
  },
  preview: {
    host: '127.0.0.1',
    port: 4173,
  },
  build: {
    outDir: 'dist',
    // The production bundle is published publicly as-is: emit no source maps.
    sourcemap: false,
  },
})
