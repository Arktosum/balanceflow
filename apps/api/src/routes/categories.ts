import { Router } from 'express'
import { db } from '../db'
import { asyncHandler } from '../middleware/asyncHandler'
import { AppError } from '../middleware/errorHandler'
import { z } from 'zod'

const router = Router()

const CreateCategorySchema = z.object({
  name: z.string().min(1, 'Name is required').max(30),
  icon: z.string().optional(),
  color: z.string().optional(),
  type: z.enum(['expense', 'income', 'both']).default('both'),
})

const UpdateCategorySchema = CreateCategorySchema.partial()

// GET /api/categories
router.get('/', asyncHandler(async (_req, res) => {
  const result = await db.query(
    'SELECT * FROM categories ORDER BY name ASC'
  )
  res.json(result.rows)
}))

// GET /api/categories/:id
router.get('/:id', asyncHandler(async (req, res) => {
  const result = await db.query(
    'SELECT * FROM categories WHERE id = $1',
    [req.params.id]
  )
  if (result.rows.length === 0) throw new AppError(404, 'Category not found')
  res.json(result.rows[0])
}))

// POST /api/categories
router.post('/', asyncHandler(async (req, res) => {
  const data = CreateCategorySchema.parse(req.body)

  // check for duplicate name
  const existing = await db.query(
    'SELECT id FROM categories WHERE LOWER(name) = LOWER($1)',
    [data.name]
  )
  if (existing.rows.length > 0) throw new AppError(409, 'Category with this name already exists')

  const result = await db.query(
    `INSERT INTO categories (name, icon, color, type)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [data.name, data.icon ?? null, data.color ?? null, data.type]
  )
  res.status(201).json(result.rows[0])
}))

// PATCH /api/categories/:id
router.patch('/:id', asyncHandler(async (req, res) => {
  const data = UpdateCategorySchema.parse(req.body)

  const existing = await db.query(
    'SELECT * FROM categories WHERE id = $1',
    [req.params.id]
  )
  if (existing.rows.length === 0) throw new AppError(404, 'Category not found')

  const category = existing.rows[0]
  const result = await db.query(
    `UPDATE categories
     SET name = $1, icon = $2, color = $3, type = $4
     WHERE id = $5
     RETURNING *`,
    [
      data.name ?? category.name,
      data.icon ?? category.icon,
      data.color ?? category.color,
      data.type ?? category.type,
      req.params.id,
    ]
  )
  res.json(result.rows[0])
}))

// DELETE /api/categories/:id
router.delete('/:id', asyncHandler(async (req, res) => {
  const existing = await db.query(
    'SELECT * FROM categories WHERE id = $1',
    [req.params.id]
  )
  if (existing.rows.length === 0) throw new AppError(404, 'Category not found')

  await db.query('DELETE FROM categories WHERE id = $1', [req.params.id])
  res.json({ message: 'Category deleted' })
}))

export { router as categoriesRouter }