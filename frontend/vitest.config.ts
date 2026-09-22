import { defineConfig, mergeConfig } from 'vitest/config'
import viteConfig from './vite.config'
export default mergeConfig(viteConfig, defineConfig({test:{server:{deps:{inline:['@material/material-color-utilities']}},environment:'jsdom',include:['src/**/*.test.ts']}}))
