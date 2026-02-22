import { Request, Response, NextFunction } from 'express'

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
    const token = req.headers['x-app-token']
    const secret = process.env.APP_SECRET

    if (!secret) {
        console.error('APP_SECRET not set!')
        return res.status(500).json({ error: 'Server misconfigured' })
    }

    if (!token || token !== secret) {
        return res.status(401).json({ error: 'Unauthorized' })
    }

    next()
}