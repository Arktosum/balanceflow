import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import './db'
import { errorHandler } from './middleware/errorHandler'

dotenv.config()

const app = express()
const PORT = process.env.PORT || 3001

app.use(express.json())
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
}))

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    app: 'BalanceFlow API',
    timestamp: new Date().toISOString(),
  })
})

app.use(errorHandler)

app.listen(PORT, () => {
  console.log(`✅ BalanceFlow API running on http://localhost:${PORT}`)
})