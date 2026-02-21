import { Router } from 'express'
import { db } from '../db'
import { asyncHandler } from '../middleware/asyncHandler'
import { z } from 'zod'

const router = Router()

const AnalyticsQuerySchema = z.object({
    period: z.enum(['day', 'week', 'month', 'year']).default('month'),
    account_id: z.string().uuid().optional(),
})

function getDateRange(period: 'day' | 'week' | 'month' | 'year') {
    const now = new Date()
    const from = new Date()

    switch (period) {
        case 'day':
            from.setHours(0, 0, 0, 0)
            break
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

// GET /api/analytics/summary
// Returns: total income, total expenses, net change, transaction count
router.get('/summary', asyncHandler(async (req, res) => {
    const { period, account_id } = AnalyticsQuerySchema.parse(req.query)
    const { from, to } = getDateRange(period)

    const accountFilter = account_id ? 'AND t.account_id = $3' : ''
    const values: any[] = [from, to]
    if (account_id) values.push(account_id)

    const result = await db.query(
        `SELECT
       COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) as total_income,
       COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) as total_expenses,
       COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount
                        WHEN t.type = 'expense' THEN -t.amount
                        ELSE 0 END), 0) as net_change,
       COUNT(*) FILTER (WHERE t.type != 'transfer') as transaction_count
     FROM transactions t
     WHERE t.is_deleted = false
       AND t.status = 'completed'
       AND t.date >= $1
       AND t.date <= $2
       AND t.type != 'transfer'
       ${accountFilter}`,
        values
    )

    // also get current total balance across all accounts
    const balanceResult = await db.query(
        `SELECT COALESCE(SUM(balance), 0) as total_balance
     FROM accounts
     WHERE is_active = true
     ${account_id ? 'AND id = $1' : ''}`,
        account_id ? [account_id] : []
    )

    res.json({
        period,
        from,
        to,
        total_income: parseFloat(result.rows[0].total_income),
        total_expenses: parseFloat(result.rows[0].total_expenses),
        net_change: parseFloat(result.rows[0].net_change),
        transaction_count: parseInt(result.rows[0].transaction_count),
        total_balance: parseFloat(balanceResult.rows[0].total_balance),
    })
}))

// GET /api/analytics/by-category
// Returns: spending per category, sorted by amount desc — for the donut chart
router.get('/by-category', asyncHandler(async (req, res) => {
    const { period, account_id } = AnalyticsQuerySchema.parse(req.query)
    const { from, to } = getDateRange(period)

    const accountFilter = account_id ? 'AND t.account_id = $3' : ''
    const values: any[] = [from, to]
    if (account_id) values.push(account_id)

    const result = await db.query(
        `SELECT
       c.id as category_id,
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

    // calculate percentages
    const rows = result.rows
    const grandTotal = rows.reduce((sum: number, r: any) => sum + parseFloat(r.total), 0)
    const withPercentage = rows.map((r: any) => ({
        ...r,
        total: parseFloat(r.total),
        transaction_count: parseInt(r.transaction_count),
        percentage: grandTotal > 0 ? Math.round((parseFloat(r.total) / grandTotal) * 100) : 0,
    }))

    res.json({ period, from, to, total: grandTotal, categories: withPercentage })
}))

// GET /api/analytics/by-merchant
// Returns: top merchants by spend — for merchant insights
router.get('/by-merchant', asyncHandler(async (req, res) => {
    const { period, account_id } = AnalyticsQuerySchema.parse(req.query)
    const { from, to } = getDateRange(period)

    const accountFilter = account_id ? 'AND t.account_id = $3' : ''
    const values: any[] = [from, to]
    if (account_id) values.push(account_id)

    const result = await db.query(
        `SELECT
       m.id as merchant_id,
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
        period,
        from,
        to,
        merchants: result.rows.map((r: any) => ({
            ...r,
            total: parseFloat(r.total),
            transaction_count: parseInt(r.transaction_count),
        })),
    })
}))

// GET /api/analytics/trends
// Returns: data points over time — for the line/area chart
router.get('/trends', asyncHandler(async (req, res) => {
    const { period, account_id } = AnalyticsQuerySchema.parse(req.query)
    const { from, to } = getDateRange(period)

    // choose the right time bucket based on period
    const dateTrunc = period === 'day' ? 'hour'
        : period === 'week' ? 'day'
            : period === 'month' ? 'day'
                : 'month' // year → monthly buckets

    const accountFilter = account_id ? 'AND t.account_id = $3' : ''
    const values: any[] = [from, to]
    if (account_id) values.push(account_id)

    const result = await db.query(
        `SELECT
       DATE_TRUNC('${dateTrunc}', t.date) as bucket,
       COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) as expenses,
       COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) as income
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
        period,
        from,
        to,
        data_points: result.rows.map((r: any) => ({
            date: r.bucket,
            expenses: parseFloat(r.expenses),
            income: parseFloat(r.income),
            net: parseFloat(r.income) - parseFloat(r.expenses),
        })),
    })
}))

export { router as analyticsRouter }