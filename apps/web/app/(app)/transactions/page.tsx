"use client";

import { useEffect, useState, useCallback } from "react";
import api from "@/lib/api";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { showToast } from "@/components/ui/Toast";
import { formatCurrency, formatDate } from "@/lib/utils";
import { Transaction, Account, Merchant, Category } from "@/lib/types";
import { X, SlidersHorizontal, Search } from "lucide-react";
import TransactionModal from "@/components/transactions/TransactionModal";
import TransactionCard from "@/components/transactions/TransactionCard";

function groupByDate(transactions: Transaction[]) {
  const groups: Record<string, Transaction[]> = {};
  for (const tx of transactions) {
    const key = formatDate(tx.date);
    if (!groups[key]) groups[key] = [];
    groups[key].push(tx);
  }
  return groups;
}

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<Transaction | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  const [search, setSearch] = useState("");

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

  const filtered = transactions.filter((tx) => {
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    return (
      tx.merchant_name?.toLowerCase().includes(q) ||
      tx.note?.toLowerCase().includes(q) ||
      tx.amount.toString().includes(q)
    );
  });

  const grouped = groupByDate(filtered);
  const hasFilters =
    filterType || filterStatus || filterAccount || filterMerchant;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Transactions</h1>
          <p className="text-gray-500 text-sm mt-1">
            {loading ? "..." : `${filtered.length} transactions`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div
            className="flex items-center gap-2 px-4 py-2 rounded-xl"
            style={{ background: "rgba(255,255,255,0.05)" }}
          >
            <Search size={16} className="text-gray-500" />
            <input
              type="text"
              placeholder="Search..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="bg-transparent text-white text-sm outline-none placeholder-gray-600 w-40"
            />
            {search && (
              <button
                onClick={() => setSearch("")}
                className="text-gray-600 hover:text-white"
              >
                <X size={14} />
              </button>
            )}
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
      </div>

      {showFilters && (
        <Card className="flex flex-wrap gap-3">
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            className="rounded-xl px-3 py-2 text-white text-sm outline-none"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <option value="" style={{ background: "#0f1119" }}>
              All Types
            </option>
            <option value="expense" style={{ background: "#0f1119" }}>
              Expense
            </option>
            <option value="income" style={{ background: "#0f1119" }}>
              Income
            </option>
            <option value="transfer" style={{ background: "#0f1119" }}>
              Transfer
            </option>
          </select>
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="rounded-xl px-3 py-2 text-white text-sm outline-none"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <option value="" style={{ background: "#0f1119" }}>
              All Statuses
            </option>
            <option value="completed" style={{ background: "#0f1119" }}>
              Completed
            </option>
            <option value="pending" style={{ background: "#0f1119" }}>
              Pending
            </option>
          </select>
          <select
            value={filterAccount}
            onChange={(e) => setFilterAccount(e.target.value)}
            className="rounded-xl px-3 py-2 text-white text-sm outline-none"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <option value="" style={{ background: "#0f1119" }}>
              All Accounts
            </option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id} style={{ background: "#0f1119" }}>
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
            <option value="" style={{ background: "#0f1119" }}>
              All Merchants
            </option>
            {merchants.map((m) => (
              <option key={m.id} value={m.id} style={{ background: "#0f1119" }}>
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
              className="px-3 py-2 rounded-xl text-sm text-red-400"
              style={{ background: "rgba(239,68,68,0.1)" }}
            >
              Clear all
            </button>
          )}
        </Card>
      )}

      {loading ? (
        <div className="flex flex-col gap-3">
          {[1, 2, 3, 4, 5].map((i) => (
            <Skeleton key={i} className="h-16" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <EmptyState
          icon="💸"
          message={
            search ? `No results for "${search}"` : "No transactions yet"
          }
          subMessage={
            search
              ? "Try a different search term"
              : "Tap + to add your first transaction"
          }
        />
      ) : (
        <div className="flex flex-col gap-6">
          {Object.entries(grouped).map(([date, txs]) => (
            <div key={date}>
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
              <div className="flex flex-col gap-2">
                {txs.map((tx) => (
                  <TransactionCard
                    key={tx.id}
                    tx={tx}
                    onClick={() => setSelected(tx)}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

      {selected && (
        <TransactionModal
          transaction={selected}
          categories={categories}
          onClose={() => setSelected(null)}
          onDeleted={(id) => {
            setTransactions((prev) => prev.filter((t) => t.id !== id));
            setSelected(null);
          }}
          onUpdated={(tx) =>
            setTransactions((prev) =>
              prev.map((t) => (t.id === tx.id ? tx : t)),
            )
          }
        />
      )}
    </div>
  );
}
