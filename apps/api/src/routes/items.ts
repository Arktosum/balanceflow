import { Router } from 'express'
import { z } from 'zod'
import { db } from '../db'
import { asyncHandler } from '../middleware/asyncHandler'
import { AppError } from '../middleware/errorHandler'

const router = Router()

const ItemSchema = z.object({
    name: z.string().min(1).max(255),
    category_id: z.string().uuid().optional(),
})

// GET /api/items
router.get('/', asyncHandler(async (req, res) => {
    const { search } = req.query

    let query = `
    SELECT 
      i.*,
      c.name as category_name,
      c.icon as category_icon,
      c.color as category_color,
      COUNT(ti.id)::int as usage_count,
      COALESCE(
        (SELECT ti2.amount 
         FROM transaction_items ti2 
         WHERE ti2.item_id = i.id 
         ORDER BY ti2.created_at DESC 
         LIMIT 1
        ), 0
      ) as last_price
    FROM items i
    LEFT JOIN categories c ON i.category_id = c.id
    LEFT JOIN transaction_items ti ON ti.item_id = i.id
  `

    const params: any[] = []

    if (search) {
        params.push(`%${search}%`)
        query += ` WHERE i.name ILIKE $1`
    }

    query += ` GROUP BY i.id, c.name, c.icon, c.color ORDER BY usage_count DESC, i.name ASC`

    const result = await db.query(query, params)
    res.json(result.rows)
}))

// POST /api/items
router.post('/', asyncHandler(async (req, res) => {
    const data = ItemSchema.parse(req.body)

    // check if item with same name exists
    const existing = await db.query(
        'SELECT * FROM items WHERE LOWER(name) = LOWER($1)',
        [data.name]
    )
    if (existing.rows.length > 0) {
        return res.json(existing.rows[0])
    }

    const result = await db.query(
        `INSERT INTO items (name, category_id)
     VALUES ($1, $2)
     RETURNING *`,
        [data.name, data.category_id ?? null]
    )
    res.status(201).json(result.rows[0])
}))

// PATCH /api/items/:id
router.patch('/:id', asyncHandler(async (req, res) => {
    const data = ItemSchema.partial().parse(req.body)

    const existing = await db.query('SELECT * FROM items WHERE id = $1', [req.params.id])
    if (existing.rows.length === 0) throw new AppError(404, 'Item not found')

    const result = await db.query(
        `UPDATE items
     SET name = COALESCE($1, name),
         category_id = COALESCE($2, category_id),
         updated_at = NOW()
     WHERE id = $3
     RETURNING *`,
        [data.name, data.category_id, req.params.id]
    )
    res.json(result.rows[0])
}))

// DELETE /api/items/:id
router.delete('/:id', asyncHandler(async (req, res) => {
    const existing = await db.query('SELECT * FROM items WHERE id = $1', [req.params.id])
    if (existing.rows.length === 0) throw new AppError(404, 'Item not found')

    // check if item is used in any transaction
    const usage = await db.query(
        'SELECT COUNT(*) FROM transaction_items WHERE item_id = $1',
        [req.params.id]
    )
    if (parseInt(usage.rows[0].count) > 0) {
        throw new AppError(400, 'Cannot delete item that is used in transactions')
    }

    await db.query('DELETE FROM items WHERE id = $1', [req.params.id])
    res.json({ success: true })
}))

export default router