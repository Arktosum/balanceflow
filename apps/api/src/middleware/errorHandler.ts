import { Request, Response, NextFunction } from 'express'
import { ZodError } from 'zod'

export class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string
  ) {
    super(message)
    this.name = 'AppError'
  }
}

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  if (err instanceof ZodError && Array.isArray(err.errors)) {
    return res.status(400).json({
      error: 'Validation failed',
      fields: err.errors.map((e) => ({
        field: e.path.join('.'),
        message: e.message,
      })),
    })
  }

  if (err instanceof AppError) {
    return res.status(err.statusCode).json({ error: err.message })
  }

  console.error('Unhandled error:', err)
  return res.status(500).json({ error: err.message || 'Internal server error' })
}