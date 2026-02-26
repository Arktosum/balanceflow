import { Router } from 'express'
import { db } from '../db'
import { asyncHandler } from '../middleware/asyncHandler'
import { z } from 'zod'

const router = Router()

const AnalyticsQuerySchema = z.object({
    period: z.enum(['week', 'month', 'year', 'all', 'custom']).default('month'),
    account_id: z.string().uuid().optional(),
    from: z.string().optional(), // ISO string, used when period=custom
    to: z.string().optional(),   // ISO string, used when period=custom
})

function getDateRange(period: string, customFrom?: string, customTo?: string): { from: string; to: string } {
    const now = new Date()

    if (period === 'custom' && customFrom && customTo) {
        return { from: customFrom, to: customTo }
    }

    if (period === 'all') {
        return { from: new Date(0).toISOString(), to: now.toISOString() }
    }

    const from = new Date()
    switch (period) {
        case 'week':
            from.setDate(now.getDate() - 7)
            break
        case 'month':
            from.setDate(1)
            from.setHours(0, 0, 0, 0)
            break
        case 'year':
            from.setMonth(0, 1)
            from.setHours(0, 0, 0, 0)
            break
    }

    return { from: from.toISOString(), to: now.toISOString() }
}

function getTrendBucket(period: string): string {
    switch (period) {
        case 'week': return 'day'
        case 'month': return 'day'
        case 'year': return 'month'
        case 'all': return 'month'
        case 'custom': return 'day'
        default: return 'day'
    }
}

// GET /api/analytics/summary
router.get('/summary', asyncHandler(async (req, res) => {
    const { period, account_id, from: qFrom, to: qTo } = AnalyticsQuerySchema.parse(req.query)
    const { from, to } = getDateRange(period, qFrom, qTo)

    const accountFilter = account_id ? 'AND t.account_id = $3' : ''
    const values: any[] = [from, to]
    if (account_id) values.push(account_id)

    const result = await db.query(
        `SELECT
       COALESCE(SUM(CASE WHEN t.type = 'income'  THEN t.amount ELSE 0 END), 0) as total_income,
       COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) as total_expenses,
       COALESCE(SUM(CASE WHEN t.type = 'income'  THEN  t.amount
                         WHEN t.type = 'expense' THEN -t.amount
                         ELSE 0 END), 0) as net_change,
       COUNT(*) FILTER (WHERE t.type != 'transfer') as transaction_count
     FROM transactions t
     WHERE t.is_deleted = false
       AND t.status = 'completed'
       AND t.type != 'transfer'
       AND t.date >= $1
       AND t.date <= $2
       ${accountFilter}`,
        values
    )

    const balanceResult = await db.query(
        `SELECT COALESCE(SUM(balance), 0) as total_balance
     FROM accounts
     WHERE is_active = true
     ${account_id ? 'AND id = $1' : ''}`,
        account_id ? [account_id] : []
    )

    res.json({
        period, from, to,
        total_income: parseFloat(result.rows[0].total_income),
        total_expenses: parseFloat(result.rows[0].total_expenses),
        net_change: parseFloat(result.rows[0].net_change),
        transaction_count: parseInt(result.rows[0].transaction_count),
        total_balance: parseFloat(balanceResult.rows[0].total_balance),
    })
}))

// GET /api/analytics/by-category
router.get('/by-category', asyncHandler(async (req, res) => {
    const { period, account_id, from: qFrom, to: qTo } = AnalyticsQuerySchema.parse(req.query)
    const { from, to } = getDateRange(period, qFrom, qTo)

    const accountFilter = account_id ? 'AND t.account_id = $3' : ''
    const values: any[] = [from, to]
    if (account_id) values.push(account_id)

    const result = await db.query(
        `SELECT
       c.id   as category_id,
       c.name as category_name,
       c.icon as category_icon,
       c.color as category_color,
       COALESCE(SUM(t.amount), 0) as total,
       COUNT(*) as transaction_count
     FROM transactions t
     LEFT JOIN categories c ON t.category_id = c.id
     WHERE t.is_deleted = false
       AND t.status = 'completed'
       AND t.type = 'expense'
       AND t.date >= $1
       AND t.date <= $2
       ${accountFilter}
     GROUP BY c.id, c.name, c.icon, c.color
     ORDER BY total DESC`,
        values
    )

    const rows = result.rows
    const grandTotal = rows.reduce((sum: number, r: any) => sum + parseFloat(r.total), 0)

    res.json({
        period, from, to,
        total: grandTotal,
        categories: rows.map((r: any) => ({
            ...r,
            total: parseFloat(r.total),
            transaction_count: parseInt(r.transaction_count),
            percentage: grandTotal > 0 ? Math.round((parseFloat(r.total) / grandTotal) * 100) : 0,
        })),
    })
}))

// GET /api/analytics/by-merchant
router.get('/by-merchant', asyncHandler(async (req, res) => {
    const { period, account_id, from: qFrom, to: qTo } = AnalyticsQuerySchema.parse(req.query)
    const { from, to } = getDateRange(period, qFrom, qTo)

    const accountFilter = account_id ? 'AND t.account_id = $3' : ''
    const values: any[] = [from, to]
    if (account_id) values.push(account_id)

    const result = await db.query(
        `SELECT
       m.id   as merchant_id,
       m.name as merchant_name,
       COALESCE(SUM(t.amount), 0) as total,
       COUNT(*) as transaction_count
     FROM transactions t
     LEFT JOIN merchants m ON t.merchant_id = m.id
     WHERE t.is_deleted = false
       AND t.status = 'completed'
       AND t.type = 'expense'
       AND t.date >= $1
       AND t.date <= $2
       ${accountFilter}
     GROUP BY m.id, m.name
     ORDER BY total DESC
     LIMIT 10`,
        values
    )

    res.json({
        period, from, to,
        merchants: result.rows.map((r: any) => ({
            ...r,
            total: parseFloat(r.total),
            transaction_count: parseInt(r.transaction_count),
        })),
    })
}))

// GET /api/analytics/trends
router.get('/trends', asyncHandler(async (req, res) => {
    const { period, account_id, from: qFrom, to: qTo } = AnalyticsQuerySchema.parse(req.query)
    const { from, to } = getDateRange(period, qFrom, qTo)
    const bucket = getTrendBucket(period)

    const accountFilter = account_id ? 'AND t.account_id = $3' : ''
    const values: any[] = [from, to]
    if (account_id) values.push(account_id)

    const result = await db.query(
        `SELECT
       DATE_TRUNC('${bucket}', t.date) as bucket,
       COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) as expenses,
       COALESCE(SUM(CASE WHEN t.type = 'income'  THEN t.amount ELSE 0 END), 0) as income
     FROM transactions t
     WHERE t.is_deleted = false
       AND t.status = 'completed'
       AND t.type != 'transfer'
       AND t.date >= $1
       AND t.date <= $2
       ${accountFilter}
     GROUP BY bucket
     ORDER BY bucket ASC`,
        values
    )

    res.json({
        period, from, to,
        data_points: result.rows.map((r: any) => ({
            date: r.bucket,
            expenses: parseFloat(r.expenses),
            income: parseFloat(r.income),
            net: parseFloat(r.income) - parseFloat(r.expenses),
        })),
    })
}))

// GET /api/analytics/by-item
// Returns top items by spend + price history per item
router.get('/by-item', asyncHandler(async (req, res) => {
    const { period, account_id, from: qFrom, to: qTo } = AnalyticsQuerySchema.parse(req.query)
    const { from, to } = getDateRange(period, qFrom, qTo)

    const accountFilter = account_id ? 'AND t.account_id = $3' : ''
    const values: any[] = [from, to]
    if (account_id) values.push(account_id)

    // Top items by total spend
    const topItemsResult = await db.query(
        `SELECT
       i.id   as item_id,
       i.name as item_name,
       c.name as category_name,
       c.icon as category_icon,
       c.color as category_color,
       COALESCE(SUM(ti.amount * ti.quantity), 0) as total_spent,
       COALESCE(AVG(ti.amount), 0)               as avg_price,
       MAX(ti.amount)                             as max_price,
       MIN(ti.amount)                             as min_price,
       COUNT(ti.id)                               as purchase_count
     FROM transaction_items ti
     JOIN items i ON ti.item_id = i.id
     JOIN transactions t ON ti.transaction_id = t.id
     LEFT JOIN categories c ON i.category_id = c.id
     WHERE t.is_deleted = false
       AND t.status = 'completed'
       AND t.type = 'expense'
       AND t.date >= $1
       AND t.date <= $2
       ${accountFilter}
     GROUP BY i.id, i.name, c.name, c.icon, c.color
     ORDER BY total_spent DESC
     LIMIT 20`,
        values
    )

    const topItems = topItemsResult.rows.map((r: any) => ({
        ...r,
        total_spent: parseFloat(r.total_spent),
        avg_price: parseFloat(r.avg_price),
        max_price: parseFloat(r.max_price),
        min_price: parseFloat(r.min_price),
        purchase_count: parseInt(r.purchase_count),
    }))

    // Price history for all top items in one query
    const itemIds = topItems.map((i: any) => i.item_id)

    let priceHistory: Record<string, { date: string; price: number; quantity: number }[]> = {}

    if (itemIds.length > 0) {
        const historyResult = await db.query(
            `SELECT
         ti.item_id,
         t.date,
         ti.amount as price,
         ti.quantity
       FROM transaction_items ti
       JOIN transactions t ON ti.transaction_id = t.id
       WHERE t.is_deleted = false
         AND t.status = 'completed'
         AND ti.item_id = ANY($1)
         AND t.date >= $2
         AND t.date <= $3
       ORDER BY ti.item_id, t.date ASC`,
            [itemIds, from, to]
        )

        // Group by item_id
        for (const row of historyResult.rows) {
            if (!priceHistory[row.item_id]) priceHistory[row.item_id] = []
            priceHistory[row.item_id].push({
                date: row.date,
                price: parseFloat(row.price),
                quantity: parseFloat(row.quantity),
            })
        }
    }

    res.json({
        period, from, to,
        top_items: topItems,
        price_history: priceHistory,
    })
}))

export { router as analyticsRouter }