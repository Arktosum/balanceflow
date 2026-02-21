import { Router } from 'express'
import { db } from '../db'
import { asyncHandler } from '../middleware/asyncHandler'
import { AppError } from '../middleware/errorHandler'
import { z } from 'zod'

const router = Router()

const CreateMerchantSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  default_category_id: z.string().uuid().optional(),
})

const UpdateMerchantSchema = CreateMerchantSchema.partial()

// GET /api/merchants — optionally filter by ?regular=true for frequent ones
router.get('/', asyncHandler(async (req, res) => {
  const { regular } = req.query

  const result = await db.query(
    `SELECT m.*, c.name as default_category_name, c.icon as default_category_icon
     FROM merchants m
     LEFT JOIN categories c ON m.default_category_id = c.id
     ${regular === 'true' ? 'WHERE m.transaction_count >= 3' : ''}
     ORDER BY m.transaction_count DESC, m.name ASC`
  )
  res.json(result.rows)
}))

// GET /api/merchants/:id
router.get('/:id', asyncHandler(async (req, res) => {
  const result = await db.query(
    `SELECT m.*, c.name as default_category_name, c.icon as default_category_icon
     FROM merchants m
     LEFT JOIN categories c ON m.default_category_id = c.id
     WHERE m.id = $1`,
    [req.params.id]
  )
  if (result.rows.length === 0) throw new AppError(404, 'Merchant not found')
  res.json(result.rows[0])
}))

// POST /api/merchants
router.post('/', asyncHandler(async (req, res) => {
  const data = CreateMerchantSchema.parse(req.body)

  // check for duplicate name
  const existing = await db.query(
    'SELECT id FROM merchants WHERE LOWER(name) = LOWER($1)',
    [data.name]
  )
  if (existing.rows.length > 0) throw new AppError(409, 'Merchant with this name already exists')

  const result = await db.query(
    `INSERT INTO merchants (name, default_category_id)
     VALUES ($1, $2)
     RETURNING *`,
    [data.name, data.default_category_id ?? null]
  )
  res.status(201).json(result.rows[0])
}))

// PATCH /api/merchants/:id
router.patch('/:id', asyncHandler(async (req, res) => {
  const data = UpdateMerchantSchema.parse(req.body)

  const existing = await db.query(
    'SELECT * FROM merchants WHERE id = $1',
    [req.params.id]
  )
  if (existing.rows.length === 0) throw new AppError(404, 'Merchant not found')

  const merchant = existing.rows[0]
  const result = await db.query(
    `UPDATE merchants
     SET name = $1, default_category_id = $2, updated_at = NOW()
     WHERE id = $3
     RETURNING *`,
    [
      data.name ?? merchant.name,
      data.default_category_id ?? merchant.default_category_id,
      req.params.id,
    ]
  )
  res.json(result.rows[0])
}))

// DELETE /api/merchants/:id
router.delete('/:id', asyncHandler(async (req, res) => {
  const existing = await db.query(
    'SELECT * FROM merchants WHERE id = $1',
    [req.params.id]
  )
  if (existing.rows.length === 0) throw new AppError(404, 'Merchant not found')

  await db.query('DELETE FROM merchants WHERE id = $1', [req.params.id])
  res.json({ message: 'Merchant deleted' })
}))

export { router as merchantsRouter }