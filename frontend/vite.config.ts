import { fileURLToPath, URL } from 'node:url'

import { readFileSync, readdirSync } from 'node:fs'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [vue(), {
    name: 'offline-print-math',
    generateBundle() {
      const root = fileURLToPath(new URL('./node_modules/katex/dist/', import.meta.url))
      for (const [source, target] of [['katex.min.css','katex.min.css'], ['katex.min.js','katex.min.js'], ['contrib/auto-render.min.js','auto-render.min.js'], ...readdirSync(root + 'fonts').map(name => ['fonts/' + name, 'fonts/' + name])]) {
        this.emitFile({type:'asset', fileName:'print-katex/' + target, source:readFileSync(root + source)})
      }
    },
  }],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    host: '0.0.0.0',
  },
})
