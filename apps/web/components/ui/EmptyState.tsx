interface EmptyStateProps {
  icon: string
  message: string
  subMessage?: string
}

export default function EmptyState({ icon, message, subMessage }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 gap-3">
      <span className="text-4xl">{icon}</span>
      <p className="text-white font-medium">{message}</p>
      {subMessage && <p className="text-gray-500 text-sm">{subMessage}</p>}
    </div>
  )
}