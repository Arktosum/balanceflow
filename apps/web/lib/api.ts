import axios from 'axios'

async function sha256(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message)
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('')
}

export async function storeToken(password: string) {
  const hash = await sha256(password)
  localStorage.setItem('bf_token', hash)
}

export function clearToken() {
  localStorage.removeItem('bf_token')
}

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: { 'Content-Type': 'application/json' },
})

api.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('bf_token')
    if (token) config.headers['x-app-token'] = token
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && typeof window !== 'undefined') {
      localStorage.removeItem('bf_token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default api