import { Pool } from 'pg'
import dotenv from 'dotenv'

dotenv.config()

export const db = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 10,
  min: 1,                          // always keep at least 1 connection alive
  idleTimeoutMillis: 60000,        // drop idle connections after 60s
  connectionTimeoutMillis: 10000,  // wait up to 10s when acquiring a connection
  allowExitOnIdle: false,          // don't let the pool die when idle
})

db.on('error', (err) => {
  console.error('Unexpected DB pool error:', err.message)
})

db.connect((err, client, release) => {
  if (err) {
    console.error('❌ Database connection failed:', err.message)
    process.exit(1)
  }
  console.log('✅ Database connected')
  release()
})