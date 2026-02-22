import { Client } from 'pg'
import dotenv from 'dotenv'

dotenv.config()

const connectionString = process.env.DATABASE_URL!

// Creates a fresh connection, runs a callback, then destroys it
export async function withDb<T>(fn: (client: Client) => Promise<T>): Promise<T> {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000,
    query_timeout: 10000,
  })
  await client.connect()
  try {
    return await fn(client)
  } finally {
    await client.end().catch(() => { })
  }
}

// Keeps backward compat — acts like a pool but creates fresh connections
export const db = {
  query: async (text: string, params?: any[]) => {
    return withDb((client) => client.query(text, params))
  },
  connect: async () => {
    const client = new Client({
      connectionString,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 10000,
    })
    await client.connect()
    return {
      query: (text: string, params?: any[]) => client.query(text, params),
      release: async (destroy?: boolean) => { await client.end().catch(() => { }) },
    }
  },
}