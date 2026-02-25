"use client";

import Card from "@/components/ui/Card";
import { formatCurrency, formatTime } from "@/lib/utils";
import { Transaction } from "@/lib/types";

export default function TransactionCard({
  tx,
  onClick,
}: {
  tx: Transaction;
  onClick: () => void;
}) {
  const amountColor =
    tx.type === "income"
      ? "#22c55e"
      : tx.type === "transfer"
        ? "#a78bfa"
        : "#ef4444";

  const amountPrefix =
    tx.type === "income" ? "+" : tx.type === "expense" ? "-" : "";

  return (
    <Card onClick={onClick} className="flex items-center gap-4 cursor-pointer">
      {/* Icon */}
      <div
        className="w-10 h-10 rounded-full flex items-center justify-center text-lg flex-shrink-0"
        style={{
          background: tx.category_color
            ? `${tx.category_color}22`
            : "rgba(108,99,255,0.15)",
        }}
      >
        {tx.category_icon ??
          (tx.type === "transfer" ? "🔄" : tx.type === "income" ? "💰" : "💸")}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-white text-sm font-medium truncate">
          {tx.merchant_name ?? tx.note ?? tx.type}
        </p>

        {tx.note && tx.merchant_name && (
          <p className="text-gray-600 text-xs truncate mt-0.5">{tx.note}</p>
        )}

        <div className="flex items-center gap-2 mt-0.5 flex-wrap">
          {tx.category_name && (
            <span
              className="text-xs px-2 py-0.5 rounded-full"
              style={{
                background: tx.category_color
                  ? `${tx.category_color}22`
                  : "rgba(108,99,255,0.15)",
                color: tx.category_color ?? "#6C63FF",
              }}
            >
              {tx.category_name}
            </span>
          )}
          <span className="text-gray-600 text-xs">{tx.account_name}</span>
          {tx.item_count > 0 && (
            <span className="text-xs text-gray-600">
              · {tx.item_count} item{tx.item_count !== 1 ? "s" : ""}
            </span>
          )}
          {tx.status === "pending" && (
            <span
              className="text-xs px-2 py-0.5 rounded-full"
              style={{ background: "rgba(245,158,11,0.1)", color: "#f59e0b" }}
            >
              pending
            </span>
          )}
        </div>
      </div>

      {/* Amount */}
      <div className="text-right flex-shrink-0">
        <p className="text-sm font-bold" style={{ color: amountColor }}>
          {amountPrefix}
          {formatCurrency(tx.amount)}
        </p>
        <p className="text-gray-600 text-xs mt-0.5">{formatTime(tx.date)}</p>
      </div>
    </Card>
  );
}
