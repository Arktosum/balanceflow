import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import './db'
import { errorHandler } from './middleware/errorHandler'
import { accountsRouter } from './routes/accounts'
import { categoriesRouter } from './routes/categories'
import { merchantsRouter } from './routes/merchants'
import { transactionsRouter } from './routes/transactions'
import { debtsRouter } from './routes/debts'
import { analyticsRouter } from './routes/analytics'
import { db } from './db'

dotenv.config()

const app = express()
const PORT = process.env.PORT || 3001

app.use(express.json())
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
}))

app.get('/health', async (_req, res) => {
  try {
    await db.query('SELECT 1')
    res.json({
      status: 'ok',
      app: 'BalanceFlow API',
      database: 'connected',
      timestamp: new Date().toISOString(),
    })
  } catch (err: any) {
    res.status(500).json({
      status: 'error',
      app: 'BalanceFlow API',
      database: 'disconnected',
      error: err.message,
      timestamp: new Date().toISOString(),
    })
  }
})

app.use('/api/accounts', accountsRouter)
app.use('/api/categories', categoriesRouter)
app.use('/api/merchants', merchantsRouter)
app.use('/api/transactions', transactionsRouter)
app.use('/api/debts', debtsRouter)
app.use('/api/analytics', analyticsRouter)

app.use(errorHandler)

app.listen(PORT, () => {
  console.log(`✅ BalanceFlow API running on http://localhost:${PORT}`)
})