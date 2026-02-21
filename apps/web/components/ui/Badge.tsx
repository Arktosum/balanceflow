import { clsx } from 'clsx'

interface BadgeProps {
  label: string
  color?: string
  className?: string
}

export default function Badge({ label, color, className }: BadgeProps) {
  return (
    <span
      className={clsx('text-xs px-2 py-1 rounded-full font-medium', className)}
      style={{ backgroundColor: color ? `${color}33` : '#6C63FF33', color: color ?? '#6C63FF' }}
    >
      {label}
    </span>
  )
}