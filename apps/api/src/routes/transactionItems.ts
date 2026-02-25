import { Router } from 'express'
import { z } from 'zod'
import { db } from '../db'
import { asyncHandler } from '../middleware/asyncHandler'
import { AppError } from '../middleware/errorHandler'

const router = Router()

const TransactionItemSchema = z.object({
  item_id: z.string().uuid(),
  amount: z.coerce.number().positive(),
  quantity: z.coerce.number().positive().default(1),
  remarks: z.string().max(500).optional(),
})

async function recalculateTransactionAmount(transactionId: string) {
  await db.query(
    `UPDATE transactions
     SET amount = (
       SELECT COALESCE(SUM(amount * quantity), 0)
       FROM transaction_items
       WHERE transaction_id = $1
     ),
     updated_at = NOW()
     WHERE id = $1`,
    [transactionId]
  )
}

// GET /api/transactions/:id/items
router.get('/:id/items', asyncHandler(async (req, res) => {
  const result = await db.query(
    `SELECT 
      ti.*,
      i.name as item_name,
      i.category_id,
      c.name as category_name,
      c.icon as category_icon,
      c.color as category_color
     FROM transaction_items ti
     JOIN items i ON ti.item_id = i.id
     LEFT JOIN categories c ON i.category_id = c.id
     WHERE ti.transaction_id = $1
     ORDER BY ti.created_at ASC`,
    [req.params.id]
  )
  res.json(result.rows)
}))

// POST /api/transactions/:id/items
router.post('/:id/items', asyncHandler(async (req, res) => {
  const data = TransactionItemSchema.parse(req.body)

  // verify transaction exists
  const tx = await db.query(
    'SELECT * FROM transactions WHERE id = $1 AND is_deleted = false',
    [req.params.id]
  )
  if (tx.rows.length === 0) throw new AppError(404, 'Transaction not found')

  // verify item exists
  const item = await db.query('SELECT * FROM items WHERE id = $1', [data.item_id])
  if (item.rows.length === 0) throw new AppError(404, 'Item not found')

  const result = await db.query(
    `INSERT INTO transaction_items (transaction_id, item_id, amount, quantity, remarks)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [req.params.id, data.item_id, data.amount, data.quantity, data.remarks ?? null]
  )

  // recalculate transaction amount
  await recalculateTransactionAmount(req.params.id)

  res.status(201).json(result.rows[0])
}))

// PATCH /api/transaction-items/:id
router.patch('/items/:id', asyncHandler(async (req, res) => {
  const data = TransactionItemSchema.partial().parse(req.body)

  const existing = await db.query(
    'SELECT * FROM transaction_items WHERE id = $1',
    [req.params.id]
  )
  if (existing.rows.length === 0) throw new AppError(404, 'Transaction item not found')

  const result = await db.query(
    `UPDATE transaction_items
     SET amount = COALESCE($1, amount),
         quantity = COALESCE($2, quantity),
         remarks = COALESCE($3, remarks)
     WHERE id = $4
     RETURNING *`,
    [data.amount, data.quantity, data.remarks, req.params.id]
  )

  await recalculateTransactionAmount(existing.rows[0].transaction_id)
  res.json(result.rows[0])
}))

// DELETE /api/transaction-items/:id
router.delete('/items/:id', asyncHandler(async (req, res) => {
  const existing = await db.query(
    'SELECT * FROM transaction_items WHERE id = $1',
    [req.params.id]
  )
  if (existing.rows.length === 0) throw new AppError(404, 'Transaction item not found')

  await db.query('DELETE FROM transaction_items WHERE id = $1', [req.params.id])
  await recalculateTransactionAmount(existing.rows[0].transaction_id)

  res.json({ success: true })
}))

export default router