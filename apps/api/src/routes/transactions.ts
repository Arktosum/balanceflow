import { Router } from 'express'
import { db } from '../db'
import { asyncHandler } from '../middleware/asyncHandler'
import { AppError } from '../middleware/errorHandler'
import { z } from 'zod'

const router = Router()

const CreateTransactionSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('expense'),
    amount: z.number().positive(),
    account_id: z.string().uuid(),
    category_id: z.string().uuid().optional(),
    merchant_id: z.string().uuid().optional(),
    note: z.string().max(500).optional(),
    date: z.string().datetime().optional(),
    status: z.enum(['completed', 'pending']).default('completed'),
  }),
  z.object({
    type: z.literal('income'),
    amount: z.number().positive(),
    account_id: z.string().uuid(),
    category_id: z.string().uuid().optional(),
    merchant_id: z.string().uuid().optional(),
    note: z.string().max(500).optional(),
    date: z.string().datetime().optional(),
    status: z.enum(['completed', 'pending']).default('completed'),
  }),
  z.object({
    type: z.literal('transfer'),
    amount: z.number().positive(),
    account_id: z.string().uuid(),
    to_account_id: z.string().uuid(),
    note: z.string().max(500).optional(),
    date: z.string().datetime().optional(),
    status: z.enum(['completed', 'pending']).default('completed'),
  }),
])

const UpdateTransactionSchema = z.object({
  amount: z.number().positive().optional(),
  category_id: z.string().uuid().optional(),
  merchant_id: z.string().uuid().optional(),
  note: z.string().max(500).optional(),
  date: z.string().datetime().optional(),
})

const QuerySchema = z.object({
  account_id: z.string().uuid().optional(),
  category_id: z.string().uuid().optional(),
  merchant_id: z.string().uuid().optional(),
  type: z.enum(['expense', 'income', 'transfer']).optional(),
  status: z.enum(['completed', 'pending']).optional(),
  from: z.string().optional(),
  to: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
})

// GET /api/transactions
router.get('/', asyncHandler(async (req, res) => {
  const query = QuerySchema.parse(req.query)

  const conditions: string[] = ['t.is_deleted = false']
  const values: any[] = []
  let i = 1

  if (query.account_id) {
    conditions.push(`(t.account_id = $${i} OR t.to_account_id = $${i})`)
    values.push(query.account_id); i++
  }
  if (query.category_id) {
    conditions.push(`t.category_id = $${i}`)
    values.push(query.category_id); i++
  }
  if (query.merchant_id) {
    conditions.push(`t.merchant_id = $${i}`)
    values.push(query.merchant_id); i++
  }
  if (query.type) {
    conditions.push(`t.type = $${i}`)
    values.push(query.type); i++
  }
  if (query.status) {
    conditions.push(`t.status = $${i}`)
    values.push(query.status); i++
  }
  if (query.from) {
    conditions.push(`t.date >= $${i}`)
    values.push(query.from); i++
  }
  if (query.to) {
    conditions.push(`t.date <= $${i}`)
    values.push(query.to); i++
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : ''

  values.push(query.limit); const limitIdx = i++
  values.push(query.offset); const offsetIdx = i++

  const result = await db.query(
    `SELECT
       t.*,
       a.name as account_name, a.type as account_type, a.color as account_color,
       ta.name as to_account_name,
       c.name as category_name, c.icon as category_icon, c.color as category_color,
       m.name as merchant_name
     FROM transactions t
     LEFT JOIN accounts a ON t.account_id = a.id
     LEFT JOIN accounts ta ON t.to_account_id = ta.id
     LEFT JOIN categories c ON t.category_id = c.id
     LEFT JOIN merchants m ON t.merchant_id = m.id
     ${where}
     ORDER BY t.date DESC
     LIMIT $${limitIdx} OFFSET $${offsetIdx}`,
    values
  )
  res.json(result.rows)
}))

// GET /api/transactions/:id
router.get('/:id', asyncHandler(async (req, res) => {
  const result = await db.query(
    `SELECT
       t.*,
       a.name as account_name, a.type as account_type, a.color as account_color,
       ta.name as to_account_name,
       c.name as category_name, c.icon as category_icon, c.color as category_color,
       m.name as merchant_name
     FROM transactions t
     LEFT JOIN accounts a ON t.account_id = a.id
     LEFT JOIN accounts ta ON t.to_account_id = ta.id
     LEFT JOIN categories c ON t.category_id = c.id
     LEFT JOIN merchants m ON t.merchant_id = m.id
     WHERE t.id = $1 AND t.is_deleted = false`,
    [req.params.id]
  )
  if (result.rows.length === 0) throw new AppError(404, 'Transaction not found')
  res.json(result.rows[0])
}))

// POST /api/transactions
router.post('/', asyncHandler(async (req, res) => {
  const data = CreateTransactionSchema.parse(req.body)

  // verify account exists
  const accountResult = await db.query(
    'SELECT * FROM accounts WHERE id = $1 AND is_active = true',
    [data.account_id]
  )
  if (accountResult.rows.length === 0) throw new AppError(404, 'Account not found')

  // for transfers, verify destination account
  if (data.type === 'transfer') {
    if (data.to_account_id === data.account_id) {
      throw new AppError(400, 'Cannot transfer to the same account')
    }
    const toAccountResult = await db.query(
      'SELECT * FROM accounts WHERE id = $1 AND is_active = true',
      [data.to_account_id]
    )
    if (toAccountResult.rows.length === 0) throw new AppError(404, 'Destination account not found')
  }

  // use a db transaction so everything succeeds or nothing does
  const client = await db.connect()
  try {
    await client.query('BEGIN')

    // insert the transaction
    const txResult = await client.query(
      `INSERT INTO transactions
         (type, amount, account_id, to_account_id, category_id, merchant_id, note, date, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        data.type,
        data.amount,
        data.account_id,
        data.type === 'transfer' ? data.to_account_id : null,
        'category_id' in data ? (data.category_id ?? null) : null,
        'merchant_id' in data ? (data.merchant_id ?? null) : null,
        data.note ?? null,
        data.date ?? new Date().toISOString(),
        data.status,
      ]
    )

    const tx = txResult.rows[0]

    // only update balances if completed
    if (data.status === 'completed') {
      if (data.type === 'expense') {
        await client.query(
          'UPDATE accounts SET balance = balance - $1, updated_at = NOW() WHERE id = $2',
          [data.amount, data.account_id]
        )
      } else if (data.type === 'income') {
        await client.query(
          'UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2',
          [data.amount, data.account_id]
        )
      } else if (data.type === 'transfer') {
        await client.query(
          'UPDATE accounts SET balance = balance - $1, updated_at = NOW() WHERE id = $2',
          [data.amount, data.account_id]
        )
        await client.query(
          'UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2',
          [data.amount, data.to_account_id]
        )
      }
    }

    // increment merchant transaction count
    if ('merchant_id' in data && data.merchant_id) {
      await client.query(
        'UPDATE merchants SET transaction_count = transaction_count + 1, updated_at = NOW() WHERE id = $1',
        [data.merchant_id]
      )
    }

    await client.query('COMMIT')
    res.status(201).json(tx)
  } catch (err) {
    await client.query('ROLLBACK')
    throw err
  } finally {
    client.release()
  }
}))

// PATCH /api/transactions/:id — only allows editing metadata, not type/amount/account
router.patch('/:id', asyncHandler(async (req, res) => {
  const data = UpdateTransactionSchema.parse(req.body)

  const existing = await db.query(
    'SELECT * FROM transactions WHERE id = $1 AND is_deleted = false',
    [req.params.id]
  )
  if (existing.rows.length === 0) throw new AppError(404, 'Transaction not found')

  const tx = existing.rows[0]
  const result = await db.query(
    `UPDATE transactions
     SET category_id = $1, merchant_id = $2, note = $3, date = $4, updated_at = NOW()
     WHERE id = $5
     RETURNING *`,
    [
      data.category_id ?? tx.category_id,
      data.merchant_id ?? tx.merchant_id,
      data.note ?? tx.note,
      data.date ?? tx.date,
      req.params.id,
    ]
  )
  res.json(result.rows[0])
}))

// DELETE /api/transactions/:id — soft delete + reverse balance
router.delete('/:id', asyncHandler(async (req, res) => {
  const existing = await db.query(
    'SELECT * FROM transactions WHERE id = $1 AND is_deleted = false',
    [req.params.id]
  )
  if (existing.rows.length === 0) throw new AppError(404, 'Transaction not found')

  const tx = existing.rows[0]
  const client = await db.connect()

  try {
    await client.query('BEGIN')

    // soft delete
    await client.query(
      'UPDATE transactions SET is_deleted = true, updated_at = NOW() WHERE id = $1',
      [tx.id]
    )

    // reverse the balance change if it was completed
    if (tx.status === 'completed') {
      if (tx.type === 'expense') {
        await client.query(
          'UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2',
          [tx.amount, tx.account_id]
        )
      } else if (tx.type === 'income') {
        await client.query(
          'UPDATE accounts SET balance = balance - $1, updated_at = NOW() WHERE id = $2',
          [tx.amount, tx.account_id]
        )
      } else if (tx.type === 'transfer') {
        await client.query(
          'UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2',
          [tx.amount, tx.account_id]
        )
        await client.query(
          'UPDATE accounts SET balance = balance - $1, updated_at = NOW() WHERE id = $2',
          [tx.amount, tx.to_account_id]
        )
      }
    }

    // decrement merchant count
    if (tx.merchant_id) {
      await client.query(
        'UPDATE merchants SET transaction_count = GREATEST(transaction_count - 1, 0), updated_at = NOW() WHERE id = $1',
        [tx.merchant_id]
      )
    }

    await client.query('COMMIT')
    res.json({ message: 'Transaction deleted' })
  } catch (err) {
    await client.query('ROLLBACK')
    throw err
  } finally {
    client.release()
  }
}))

export { router as transactionsRouter }