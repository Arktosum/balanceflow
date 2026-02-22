import { Pool } from 'pg'
import dotenv from 'dotenv'

dotenv.config()

export const db = new Pool({
  connectionString: process.env.DATABASE_URL + '?sslmode=require',
  ssl: { rejectUnauthorized: false },
  max: 10,
  min: 2,
  idleTimeoutMillis: 60000,
  connectionTimeoutMillis: 10000,
  allowExitOnIdle: false,
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