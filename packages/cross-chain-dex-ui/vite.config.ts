import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': '/src',
    },
  },
  server: {
    proxy: {
      '/api/builder': {
        target: 'http://127.0.0.1:4545',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/builder/, ''),
      },
    },
  },
})
