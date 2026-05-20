import { httpGet } from './http'

import type { UserMeResponse } from '@/types/user'

export function getCurrentUser() {
  return httpGet<UserMeResponse>('/api/v1/users/me')
}
