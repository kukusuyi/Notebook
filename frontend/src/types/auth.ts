export interface RegisterPayload {
  username: string
  password: string
  email: string
}

export interface LoginPayload {
  username: string
  password: string
}

export interface AuthResponse {
  user_id: number
  username: string
  token: string
}
