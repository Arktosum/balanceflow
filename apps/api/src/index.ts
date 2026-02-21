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