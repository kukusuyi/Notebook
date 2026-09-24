// Imported first: it copies pre-rename storage keys before any module reads them.
import './utils/storage-migration'

import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import 'element-plus/theme-chalk/dark/css-vars.css'
import { initAppearance } from './theme/appearance'
import 'katex/dist/katex.min.css'
import { createPinia } from 'pinia'
import { createApp } from 'vue'

import App from './App.vue'
import router from './router'
import './assets/styles/index.css'

initAppearance()
const app = createApp(App)

app.use(createPinia())
app.use(router)
app.use(ElementPlus)
app.mount('#app')
