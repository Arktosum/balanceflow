import { Router } from 'express'
import { db } from '../db'
import { asyncHandler } from '../middleware/asyncHandler'
import { AppError } from '../middleware/errorHandler'
import { z } from 'zod'

const router = Router()

const CreateDebtSchema = z.object({
    transaction_id: z.string().uuid(),
    person_name: z.string().min(1, 'Person name is required').max(100),
    direction: z.enum(['i_owe', 'they_owe']),
})

// GET /api/debts — get all unsettled debts by default
router.get('/', asyncHandler(async (req, res) => {
    const { settled } = req.query

    const result = await db.query(
        `SELECT
       d.*,
       t.amount, t.note, t.date, t.account_id,
       a.name as account_name
     FROM debts d
     JOIN transactions t ON d.transaction_id = t.id
     JOIN accounts a ON t.account_id = a.id
     WHERE ${settled === 'true' ? 'd.settled_at IS NOT NULL' : 'd.settled_at IS NULL'}
     ORDER BY t.date DESC`
    )
    res.json(result.rows)
}))

// GET /api/debts/:id
router.get('/:id', asyncHandler(async (req, res) => {
    const result = await db.query(
        `SELECT
       d.*,
       t.amount, t.note, t.date, t.account_id,
       a.name as account_name
     FROM debts d
     JOIN transactions t ON d.transaction_id = t.id
     JOIN accounts a ON t.account_id = a.id
     WHERE d.id = $1`,
        [req.params.id]
    )
    if (result.rows.length === 0) throw new AppError(404, 'Debt not found')
    res.json(result.rows[0])
}))

// POST /api/debts — attach debt info to a pending transaction
router.post('/', asyncHandler(async (req, res) => {
    const data = CreateDebtSchema.parse(req.body)

    // verify the transaction exists and is pending
    const txResult = await db.query(
        'SELECT * FROM transactions WHERE id = $1 AND is_deleted = false',
        [data.transaction_id]
    )
    if (txResult.rows.length === 0) throw new AppError(404, 'Transaction not found')
    if (txResult.rows[0].status !== 'pending') {
        throw new AppError(400, 'Debt can only be attached to a pending transaction')
    }

    // check if debt already exists for this transaction
    const existing = await db.query(
        'SELECT id FROM debts WHERE transaction_id = $1',
        [data.transaction_id]
    )
    if (existing.rows.length > 0) throw new AppError(409, 'Debt already exists for this transaction')

    const result = await db.query(
        `INSERT INTO debts (transaction_id, person_name, direction)
     VALUES ($1, $2, $3)
     RETURNING *`,
        [data.transaction_id, data.person_name, data.direction]
    )
    res.status(201).json(result.rows[0])
}))

// PATCH /api/debts/:id/settle — mark a debt as settled and complete the transaction
router.patch('/:id/settle', asyncHandler(async (req, res) => {
    const debtResult = await db.query(
        'SELECT * FROM debts WHERE id = $1',
        [req.params.id]
    )
    if (debtResult.rows.length === 0) throw new AppError(404, 'Debt not found')

    const debt = debtResult.rows[0]
    if (debt.settled_at) throw new AppError(400, 'Debt is already settled')

    // get the transaction
    const txResult = await db.query(
        'SELECT * FROM transactions WHERE id = $1',
        [debt.transaction_id]
    )
    const tx = txResult.rows[0]

    const client = await db.connect()
    try {
        await client.query('BEGIN')

        // mark debt as settled
        await client.query(
            'UPDATE debts SET settled_at = NOW() WHERE id = $1',
            [debt.id]
        )

        // mark transaction as completed
        await client.query(
            'UPDATE transactions SET status = $1, updated_at = NOW() WHERE id = $2',
            ['completed', tx.id]
        )

        // now apply the balance change that was deferred
        if (tx.type === 'expense') {
            await client.query(
                'UPDATE accounts SET balance = balance - $1, updated_at = NOW() WHERE id = $2',
                [tx.amount, tx.account_id]
            )
        } else if (tx.type === 'income') {
            await client.query(
                'UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2',
                [tx.amount, tx.account_id]
            )
        }

        await client.query('COMMIT')
        res.json({ message: 'Debt settled successfully' })
    } catch (err) {
        await client.query('ROLLBACK')
        throw err
    } finally {
        client.release()
    }
}))

// DELETE /api/debts/:id — delete an unsettled debt and its transaction
router.delete('/:id', asyncHandler(async (req, res) => {
    const debtResult = await db.query(
        'SELECT * FROM debts WHERE id = $1',
        [req.params.id]
    )
    if (debtResult.rows.length === 0) throw new AppError(404, 'Debt not found')
    if (debtResult.rows[0].settled_at) throw new AppError(400, 'Cannot delete a settled debt')

    await db.query('DELETE FROM debts WHERE id = $1', [req.params.id])
    await db.query(
        'UPDATE transactions SET is_deleted = true, updated_at = NOW() WHERE id = $1',
        [debtResult.rows[0].transaction_id]
    )

    res.json({ message: 'Debt deleted' })
}))

export { router as debtsRouter }