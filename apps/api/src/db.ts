import { Pool } from 'pg'
import dotenv from 'dotenv'

dotenv.config()

export const db = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
})

db.connect((err, client, release) => {
  if (err) {
    console.error('❌ Database connection failed:', err.message)
    process.exit(1)
  }
  console.log('✅ Database connected')
  release()
})