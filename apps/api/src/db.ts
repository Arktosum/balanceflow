import { Pool } from 'pg'
import dotenv from 'dotenv'

dotenv.config()

const connectionString = process.env.DATABASE_URL!

const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false },
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
})

// Creates a fresh connection, runs a callback, then destroys it
export async function withDb<T>(fn: (client: any) => Promise<T>): Promise<T> {
  const client = await pool.connect()
  try {
    return await fn(client)
  } finally {
    client.release()
  }
}

// Keeps backward compat — acts like a pool
export const db = {
  query: async (text: string, params?: any[]) => {
    return pool.query(text, params)
  },
  connect: async () => {
    const client = await pool.connect()
    return {
      query: (text: string, params?: any[]) => client.query(text, params),
      release: async (destroy?: boolean) => { client.release(destroy) },
    }
  },
}