import { Request, Response, NextFunction } from 'express'
import crypto from 'crypto'

function hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex')
}

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
    const token = req.headers['x-app-token'] as string
    const secret = process.env.APP_SECRET

    if (!secret) {
        return res.status(500).json({ error: 'Server misconfigured' })
    }

    if (!token) {
        return res.status(401).json({ error: 'Unauthorized' })
    }

    // accept either the raw password or its sha256 hash
    const tokenIsValid =
        token === secret ||
        token === hashToken(secret)

    if (!tokenIsValid) {
        return res.status(401).json({ error: 'Unauthorized' })
    }

    next()
}