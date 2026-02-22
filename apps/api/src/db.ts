import { Pool } from 'pg'
import dotenv from 'dotenv'

dotenv.config()

export const db = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 3,
  idleTimeoutMillis: 0,
  connectionTimeoutMillis: 10000,
})

db.on('error', (_err) => {
  // silently recover — pool will reconnect on next query
})

export async function checkDb() {
  const client = await db.connect()
  try {
    await client.query('SELECT 1')
    return true
  } finally {
    client.release(true) // true = discard connection, don't return to pool
  }
}