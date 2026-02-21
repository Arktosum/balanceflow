import { Router } from 'express'
import { db } from '../db'
import { asyncHandler } from '../middleware/asyncHandler'
import { AppError } from '../middleware/errorHandler'
import { z } from 'zod'

const router = Router()

const CreateAccountSchema = z.object({
  name: z.string().min(1, 'Name is required').max(50),
  type: z.enum(['cash', 'bank', 'wallet']),
  balance: z.number().default(0),
  currency: z.string().default('INR'),
  color: z.string().optional(),
})

const UpdateAccountSchema = CreateAccountSchema.partial()

// GET /api/accounts — get all accounts
router.get('/', asyncHandler(async (_req, res) => {
  const result = await db.query(
    'SELECT * FROM accounts WHERE is_active = true ORDER BY created_at ASC'
  )
  res.json(result.rows)
}))

// GET /api/accounts/:id — get single account
router.get('/:id', asyncHandler(async (req, res) => {
  const result = await db.query(
    'SELECT * FROM accounts WHERE id = $1 AND is_active = true',
    [req.params.id]
  )
  if (result.rows.length === 0) throw new AppError(404, 'Account not found')
  res.json(result.rows[0])
}))

// POST /api/accounts — create account
router.post('/', asyncHandler(async (req, res) => {
  const data = CreateAccountSchema.parse(req.body)
  const result = await db.query(
    `INSERT INTO accounts (name, type, balance, currency, color)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [data.name, data.type, data.balance, data.currency, data.color ?? null]
  )
  res.status(201).json(result.rows[0])
}))

// PATCH /api/accounts/:id — update account
router.patch('/:id', asyncHandler(async (req, res) => {
  const data = UpdateAccountSchema.parse(req.body)
  const existing = await db.query('SELECT * FROM accounts WHERE id = $1 AND is_active = true', [req.params.id])

  if (existing.rows.length === 0) throw new AppError(404, 'Account not found')

  const account = existing.rows[0]
  const result = await db.query(
    `UPDATE accounts
     SET name = $1, type = $2, currency = $3, color = $4, updated_at = NOW()
     WHERE id = $5
     RETURNING *`,
    [
      data.name ?? account.name,
      data.type ?? account.type,
      data.currency ?? account.currency,
      data.color ?? account.color,
      req.params.id,
    ]
  )
  res.json(result.rows[0])
}))

// DELETE /api/accounts/:id — soft delete (set is_active = false)
router.delete('/:id', asyncHandler(async (req, res) => {
  const existing = await db.query('SELECT * FROM accounts WHERE id = $1 AND is_active = true', [req.params.id])

  if (existing.rows.length === 0) throw new AppError(404, 'Account not found')

  await db.query(
    'UPDATE accounts SET is_active = false, updated_at = NOW() WHERE id = $1',
    [req.params.id]
  )
  res.json({ message: 'Account deleted' })
}))

export { router as accountsRouter }