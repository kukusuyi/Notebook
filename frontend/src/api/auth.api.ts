import { httpPost } from './http'

import type { AuthResponse, LoginPayload, RegisterPayload } from '@/types/auth'

export function login(payload: LoginPayload) {
  return httpPost<AuthResponse>('/api/v1/auth/login', payload)
}

export function register(payload: RegisterPayload) {
  return httpPost<AuthResponse>('/api/v1/auth/register', payload)
}
