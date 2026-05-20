import axios, { AxiosError } from 'axios'

import type { ApiEnvelope } from '@/types/common'
import { clearAuthState, getAuthToken } from '@/utils/auth'

function resolveBaseURL(): string {
  const saved = window.localStorage.getItem('math-notebook:api-base-url')
  return saved || import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'
}

export function getApiBaseURL(): string {
  return resolveBaseURL()
}

const client = axios.create({
  baseURL: resolveBaseURL(),
  timeout: 30000,
})

client.interceptors.request.use((config) => {
  const token = getAuthToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }

  return config
})

client.interceptors.response.use(
  (response) => {
    const payload = response.data as ApiEnvelope<unknown>

    if (payload && typeof payload.code === 'number') {
      if (payload.code !== 0) {
        return Promise.reject(new Error(payload.message || '请求失败'))
      }

      response.data = payload.data
    }

    return response
  },
  (error: AxiosError<ApiEnvelope<unknown>>) => {
    if (error.response?.status === 401) {
      clearAuthState()
      const path = window.location.pathname
      if (!path.startsWith('/auth')) {
        const redirect = `${path}${window.location.search}`
        window.location.href = `/auth?redirect=${encodeURIComponent(redirect)}`
      }
    }

    const message =
      error.response?.data?.message ||
      error.message ||
      '网络请求失败，请检查后端服务是否已启动。'

    return Promise.reject(new Error(message))
  },
)

export async function httpGet<T>(url: string, params?: object): Promise<T> {
  const response = await client.get<T>(url, { params })
  return response.data
}

export async function httpPost<T>(
  url: string,
  data?: unknown,
  config?: Record<string, unknown>,
): Promise<T> {
  const response = await client.post<T>(url, data, config)
  return response.data
}

export async function httpPut<T>(url: string, data?: unknown): Promise<T> {
  const response = await client.put<T>(url, data)
  return response.data
}

export async function httpDelete<T>(url: string): Promise<T> {
  const response = await client.delete<T>(url)
  return response.data
}
