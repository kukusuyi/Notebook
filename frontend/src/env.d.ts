/// <reference types="vite/client" />

declare module 'katex/contrib/auto-render' {
  interface AutoRenderDelimiter {
    left: string
    right: string
    display: boolean
  }

  interface AutoRenderOptions {
    delimiters?: AutoRenderDelimiter[]
    throwOnError?: boolean
    strict?: 'ignore' | 'warn' | 'error' | ((errorCode: string, errorMsg: string) => 'ignore' | 'warn' | 'error')
  }

  export default function renderMathInElement(element: HTMLElement, options?: AutoRenderOptions): void
}
