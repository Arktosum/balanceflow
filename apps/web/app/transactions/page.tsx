"use client";

import { useEffect, useState, useCallback } from "react";
import api from "@/lib/api";
import { Transaction, Account, Merchant, Category } from "@/lib/types";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { showToast } from "@/components/ui/Toast";
import { Trash2, Pencil, X, Check, SlidersHorizontal } from "lucide-react";

import { formatCurrency, formatDate, formatTime } from "@/lib/utils";

function groupByDate(transactions: Transaction[]) {
  const groups: Record<string, Transaction[]> = {};
  for (const tx of transactions) {
    const key = formatDate(tx.date);
    if (!groups[key]) groups[key] = [];
    groups[key].push(tx);
  }
  return groups;
}

// Transaction detail/edit modal
function TransactionModal({
  transaction,
  categories,
  onClose,
  onDeleted,
  onUpdated,
}: {
  transaction: Transaction;
  categories: Category[];
  onClose: () => void;
  onDeleted: (id: string) => void;
  onUpdated: (tx: Transaction) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [note, setNote] = useState(transaction.note ?? "");
  const [categoryId, setCategoryId] = useState(transaction.category_id ?? "");
  const [deleting, setDeleting] = useState(false);
  const [saving, setSaving] = useState(false);

  const [amount, setAmount] = useState(transaction.amount);
  const [dateValue, setDateValue] = useState(() => {
    const d = new Date(transaction.date);
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 16);
  });
  const [confirmDelete, setConfirmDelete] = useState(false);
  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [onClose]);

  async function handleDelete() {
    setDeleting(true);
    try {
      await api.delete(`/api/transactions/${transaction.id}`);
      showToast("success", "Transaction deleted");
      onDeleted(transaction.id);
      onClose();
      window.dispatchEvent(new Event("transaction-added"));
    } catch {
      showToast("error", "Failed to delete transaction");
    } finally {
      setDeleting(false);
    }
  }

  async function handleSave() {
    setSaving(true);
    try {
      const res = await api.patch(`/api/transactions/${transaction.id}`, {
        note: note || undefined,
        category_id: categoryId || undefined,
        amount: Number(amount),
        date: new Date(dateValue).toISOString(),
      });
      showToast("success", "Transaction updated");
      onUpdated(res.data);
      onClose();
    } catch {
      showToast("error", "Failed to update transaction");
    } finally {
      setSaving(false);
    }
  }

  const amountColor =
    transaction.type === "income"
      ? "#22c55e"
      : transaction.type === "transfer"
        ? "#a78bfa"
        : "#ef4444";

  const amountPrefix =
    transaction.type === "income"
      ? "+"
      : transaction.type === "expense"
        ? "-"
        : "";

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center"
      style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)" }}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        className="w-full max-w-lg rounded-t-3xl p-6 flex flex-col gap-5"
        style={{
          background: "rgba(20,22,35,0.98)",
          border: "1px solid rgba(255,255,255,0.1)",
          backdropFilter: "blur(20px)",
        }}
      >
        {/* Header */}
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold text-white">Transaction Details</h2>
          <div className="flex items-center gap-2">
            {!editing && (
              <button
                onClick={() => setEditing(true)}
                className="p-2 rounded-lg text-gray-400 hover:text-white transition-colors"
                style={{ background: "rgba(255,255,255,0.05)" }}
              >
                <Pencil size={16} />
              </button>
            )}
            <button
              onClick={onClose}
              className="p-2 rounded-lg text-gray-400 hover:text-white transition-colors"
              style={{ background: "rgba(255,255,255,0.05)" }}
            >
              <X size={16} />
            </button>
          </div>
        </div>

        {/* Amount */}
        <div className="text-center py-4">
          {editing ? (
            <div
              className="flex items-center justify-center gap-2 rounded-xl px-4 py-3 mx-auto w-48"
              style={{ background: "rgba(255,255,255,0.06)" }}
            >
              <span className="text-gray-400 text-lg">₹</span>
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(parseFloat(e.target.value))}
                className="bg-transparent text-white text-2xl font-bold outline-none w-32 text-center"
              />
            </div>
          ) : (
            <p className="text-4xl font-bold" style={{ color: amountColor }}>
              {amountPrefix}
              {formatCurrency(transaction.amount)}
            </p>
          )}
          <p className="text-gray-500 text-sm mt-1 capitalize">
            {transaction.type}
          </p>
        </div>

        {/* Details */}
        <div className="flex flex-col gap-3">
          <div
            className="flex justify-between items-center py-2 border-b"
            style={{ borderColor: "rgba(255,255,255,0.06)" }}
          >
            <span className="text-gray-500 text-sm">Account</span>
            <span className="text-white text-sm font-medium">
              {transaction.account_name}
            </span>
          </div>

          {transaction.to_account_name && (
            <div
              className="flex justify-between items-center py-2 border-b"
              style={{ borderColor: "rgba(255,255,255,0.06)" }}
            >
              <span className="text-gray-500 text-sm">To Account</span>
              <span className="text-white text-sm font-medium">
                {transaction.to_account_name}
              </span>
            </div>
          )}

          {transaction.merchant_name && (
            <div
              className="flex justify-between items-center py-2 border-b"
              style={{ borderColor: "rgba(255,255,255,0.06)" }}
            >
              <span className="text-gray-500 text-sm">Merchant</span>
              <span className="text-white text-sm font-medium">
                {transaction.merchant_name}
              </span>
            </div>
          )}


          <div
            className="flex justify-between items-center py-2 border-b"
            style={{ borderColor: "rgba(255,255,255,0.06)" }}
          >
            <span className="text-gray-500 text-sm">Status</span>
            <span
              className="text-xs px-2 py-1 rounded-full font-medium capitalize"
              style={{
                background:
                  transaction.status === "completed"
                    ? "rgba(34,197,94,0.1)"
                    : "rgba(245,158,11,0.1)",
                color:
                  transaction.status === "completed" ? "#22c55e" : "#f59e0b",
              }}
            >
              {transaction.status}
            </span>
          </div>

          {/* Editable fields */}
          <div
            className="flex justify-between items-center py-2 border-b"
            style={{ borderColor: "rgba(255,255,255,0.06)" }}
          >
            <span className="text-gray-500 text-sm">Date</span>
            {editing ? (
              <input
                type="datetime-local"
                value={dateValue}
                onChange={(e) => setDateValue(e.target.value)}
                className="rounded-lg px-3 py-1 text-white text-sm outline-none"
                style={{
                  background: "rgba(255,255,255,0.08)",
                  colorScheme: "dark",
                }}
              />
            ) : (
              <span className="text-white text-sm font-medium">
                {formatDate(transaction.date)} at {formatTime(transaction.date)}
              </span>
            )}
          </div>

          <div
            className="flex justify-between items-center py-2 border-b"
            style={{ borderColor: "rgba(255,255,255,0.06)" }}
          >
            <span className="text-gray-500 text-sm">Category</span>
            {editing ? (
              <select
                value={categoryId}
                onChange={(e) => setCategoryId(e.target.value)}
                className="rounded-lg px-3 py-1 text-white text-sm outline-none"
                style={{ background: "rgba(255,255,255,0.08)" }}
              >
                <option value="" style={{ background: "#1a1d2e" }}>
                  None
                </option>
                {categories.map((c) => (
                  <option
                    key={c.id}
                    value={c.id}
                    style={{ background: "#1a1d2e" }}
                  >
                    {c.icon} {c.name}
                  </option>
                ))}
              </select>
            ) : (
              <span className="text-white text-sm font-medium">
                {transaction.category_icon}{" "}
                {transaction.category_name ?? "None"}
              </span>
            )}
          </div>

          <div className="flex justify-between items-center py-2">
            <span className="text-gray-500 text-sm">Note</span>
            {editing ? (
              <input
                type="text"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="Add a note"
                className="rounded-lg px-3 py-1 text-white text-sm outline-none placeholder-gray-700"
                style={{ background: "rgba(255,255,255,0.08)" }}
              />
            ) : (
              <span className="text-white text-sm font-medium">
                {transaction.note ?? "—"}
              </span>
            )}
          </div>
        </div>

        {/* Actions */}
        {editing ? (
          <div className="flex gap-3">
            <button
              onClick={() => setEditing(false)}
              className="flex-1 py-3 rounded-xl text-gray-400 text-sm font-medium transition-colors"
              style={{ background: "rgba(255,255,255,0.05)" }}
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={saving}
              className="flex-1 py-3 rounded-xl text-white text-sm font-semibold disabled:opacity-50"
              style={{ background: "#6C63FF" }}
            >
              {saving ? "Saving..." : "Save Changes"}
            </button>
          </div>
        ) : confirmDelete ? (
          <div className="flex flex-col gap-2">
            <p className="text-center text-sm text-gray-400">
              Are you sure? This cannot be undone.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setConfirmDelete(false)}
                className="flex-1 py-3 rounded-xl text-gray-400 text-sm font-medium"
                style={{ background: "rgba(255,255,255,0.05)" }}
              >
                Cancel
              </button>
              <button
                onClick={handleDelete}
                disabled={deleting}
                className="flex-1 py-3 rounded-xl text-white text-sm font-semibold disabled:opacity-50"
                style={{ background: "#ef4444" }}
              >
                {deleting ? "Deleting..." : "Yes, Delete"}
              </button>
            </div>
          </div>
        ) : (
          <div className="flex gap-3">
            <button
              onClick={() => setEditing(true)}
              className="flex-1 py-3 rounded-xl text-sm font-medium"
              style={{ background: "rgba(108,99,255,0.1)", color: "#6C63FF" }}
            >
              Edit
            </button>
            <button
              onClick={() => setConfirmDelete(true)}
              className="py-3 px-4 rounded-xl text-sm font-medium"
              style={{ background: "rgba(239,68,68,0.1)", color: "#ef4444" }}
            >
              <Trash2 size={16} />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<Transaction | null>(null);
  const [showFilters, setShowFilters] = useState(false);

  // filters
  const [filterType, setFilterType] = useState("");
  const [filterStatus, setFilterStatus] = useState("");
  const [filterAccount, setFilterAccount] = useState("");
  const [filterMerchant, setFilterMerchant] = useState("");

  const fetchTransactions = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (filterType) params.append("type", filterType);
      if (filterStatus) params.append("status", filterStatus);
      if (filterAccount) params.append("account_id", filterAccount);
      if (filterMerchant) params.append("merchant_id", filterMerchant);

      const res = await api.get(`/api/transactions?${params.toString()}`);
      setTransactions(res.data);
    } catch {
      showToast("error", "Could not load transactions");
    } finally {
      setLoading(false);
    }
  }, [filterType, filterStatus, filterAccount, filterMerchant]);

  useEffect(() => {
    fetchTransactions();
    api.get("/api/accounts").then((r) => setAccounts(r.data));
    api.get("/api/merchants").then((r) => setMerchants(r.data));
    api.get("/api/categories").then((r) => setCategories(r.data));
  }, [fetchTransactions]);

  useEffect(() => {
    window.addEventListener("transaction-added", fetchTransactions);
    return () =>
      window.removeEventListener("transaction-added", fetchTransactions);
  }, [fetchTransactions]);

  function handleDeleted(id: string) {
    setTransactions((prev) => prev.filter((t) => t.id !== id));
  }

  function handleUpdated(tx: Transaction) {
    setTransactions((prev) => prev.map((t) => (t.id === tx.id ? tx : t)));
  }

  const grouped = groupByDate(transactions);
  const hasFilters =
    filterType || filterStatus || filterAccount || filterMerchant;

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Transactions</h1>
          <p className="text-gray-500 text-sm mt-1">
            {loading ? "..." : `${transactions.length} transactions`}
          </p>
        </div>
        <button
          onClick={() => setShowFilters(!showFilters)}
          className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-colors"
          style={{
            background: hasFilters
              ? "rgba(108,99,255,0.2)"
              : "rgba(255,255,255,0.05)",
            color: hasFilters ? "#6C63FF" : "#9ca3af",
            border: hasFilters
              ? "1px solid rgba(108,99,255,0.3)"
              : "1px solid transparent",
          }}
        >
          <SlidersHorizontal size={16} />
          Filters {hasFilters && "•"}
        </button>
      </div>

      {/* Filters */}
      {showFilters && (
        <Card className="flex flex-wrap gap-3">
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            className="rounded-xl px-3 py-2 text-white text-sm outline-none"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <option value="" style={{ background: "#1a1d2e" }}>
              All Types
            </option>
            <option value="expense" style={{ background: "#1a1d2e" }}>
              Expense
            </option>
            <option value="income" style={{ background: "#1a1d2e" }}>
              Income
            </option>
            <option value="transfer" style={{ background: "#1a1d2e" }}>
              Transfer
            </option>
          </select>

          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="rounded-xl px-3 py-2 text-white text-sm outline-none"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <option value="" style={{ background: "#1a1d2e" }}>
              All Statuses
            </option>
            <option value="completed" style={{ background: "#1a1d2e" }}>
              Completed
            </option>
            <option value="pending" style={{ background: "#1a1d2e" }}>
              Pending
            </option>
          </select>

          <select
            value={filterAccount}
            onChange={(e) => setFilterAccount(e.target.value)}
            className="rounded-xl px-3 py-2 text-white text-sm outline-none"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <option value="" style={{ background: "#1a1d2e" }}>
              All Accounts
            </option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id} style={{ background: "#1a1d2e" }}>
                {a.name}
              </option>
            ))}
          </select>

          <select
            value={filterMerchant}
            onChange={(e) => setFilterMerchant(e.target.value)}
            className="rounded-xl px-3 py-2 text-white text-sm outline-none"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <option value="" style={{ background: "#1a1d2e" }}>
              All Merchants
            </option>
            {merchants.map((m) => (
              <option key={m.id} value={m.id} style={{ background: "#1a1d2e" }}>
                {m.name}
              </option>
            ))}
          </select>

          {hasFilters && (
            <button
              onClick={() => {
                setFilterType("");
                setFilterStatus("");
                setFilterAccount("");
                setFilterMerchant("");
              }}
              className="px-3 py-2 rounded-xl text-sm text-red-400 hover:text-red-300 transition-colors"
              style={{ background: "rgba(239,68,68,0.1)" }}
            >
              Clear all
            </button>
          )}
        </Card>
      )}

      {/* Transaction feed */}
      {loading ? (
        <div className="flex flex-col gap-4">
          {[1, 2, 3, 4, 5].map((i) => (
            <Skeleton key={i} className="h-16" />
          ))}
        </div>
      ) : transactions.length === 0 ? (
        <EmptyState
          icon="💸"
          message="No transactions yet"
          subMessage="Tap the + button to add your first transaction"
        />
      ) : (
        <div className="flex flex-col gap-6">
          {Object.entries(grouped).map(([date, txs]) => (
            <div key={date}>
              {/* Date header */}
              <div className="flex items-center gap-3 mb-3">
                <p className="text-sm font-semibold text-gray-400">{date}</p>
                <div
                  className="flex-1 h-px"
                  style={{ background: "rgba(255,255,255,0.06)" }}
                />
                <p className="text-xs text-gray-600">
                  {formatCurrency(
                    txs.reduce(
                      (sum, tx) =>
                        tx.type === "expense"
                          ? sum - tx.amount
                          : tx.type === "income"
                            ? sum + tx.amount
                            : sum,
                      0,
                    ),
                  )}
                </p>
              </div>

              {/* Transactions */}
              <div className="flex flex-col gap-2">
                {txs.map((tx) => {
                  const amountColor =
                    tx.type === "income"
                      ? "#22c55e"
                      : tx.type === "transfer"
                        ? "#a78bfa"
                        : "#ef4444";
                  const amountPrefix =
                    tx.type === "income"
                      ? "+"
                      : tx.type === "expense"
                        ? "-"
                        : "";

                  return (
                    <Card
                      key={tx.id}
                      onClick={() => setSelected(tx)}
                      className="flex items-center gap-4"
                    >
                      {/* Category icon */}
                      <div
                        className="w-10 h-10 rounded-full flex items-center justify-center text-lg flex-shrink-0"
                        style={{
                          background: tx.category_color
                            ? `${tx.category_color}22`
                            : "rgba(108,99,255,0.15)",
                        }}
                      >
                        {tx.category_icon ??
                          (tx.type === "transfer"
                            ? "🔄"
                            : tx.type === "income"
                              ? "💰"
                              : "💸")}
                      </div>
                      {/* Info */}
                      <div className="flex-1 min-w-0">
                        <p className="text-white text-sm font-medium truncate">
                          {tx.merchant_name ?? tx.note ?? tx.type}
                        </p>
                        {tx.note && tx.merchant_name && (
                          <p className="text-gray-600 text-xs truncate mt-0.5">
                            {tx.note}
                          </p>
                        )}
                        <div className="flex items-center gap-2 mt-0.5">
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
                          <span className="text-gray-600 text-xs">
                            {tx.account_name}
                          </span>
                          {tx.status === "pending" && (
                            <span
                              className="text-xs px-2 py-0.5 rounded-full"
                              style={{
                                background: "rgba(245,158,11,0.1)",
                                color: "#f59e0b",
                              }}
                            >
                              pending
                            </span>
                          )}
                        </div>
                      </div>

                      {/* Amount + time */}
                      <div className="text-right flex-shrink-0">
                        <p
                          className="text-sm font-bold"
                          style={{ color: amountColor }}
                        >
                          {amountPrefix}
                          {formatCurrency(tx.amount)}
                        </p>
                        <p className="text-gray-600 text-xs mt-0.5">
                          {formatTime(tx.date)}
                        </p>
                      </div>
                    </Card>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Transaction detail modal */}
      {selected && (
        <TransactionModal
          transaction={selected}
          categories={categories}
          onClose={() => setSelected(null)}
          onDeleted={handleDeleted}
          onUpdated={handleUpdated}
        />
      )}
    </div>
  );
}
