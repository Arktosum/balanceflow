"use client";

import { useEffect, useState, useCallback } from "react";
import api from "@/lib/api";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { showToast } from "@/components/ui/Toast";
import { formatCurrency, formatDate, formatTime } from "@/lib/utils";
import { Item } from "@/lib/types";
import {
  Trash2,
  Pencil,
  X,
  Check,
  SlidersHorizontal,
  Search,
  Plus,
} from "lucide-react";
import {
  Transaction,
  Account,
  Merchant,
  Category,
  TransactionItem,
} from "@/lib/types";

function groupByDate(transactions: Transaction[]) {
  const groups: Record<string, Transaction[]> = {};
  for (const tx of transactions) {
    const key = formatDate(tx.date);
    if (!groups[key]) groups[key] = [];
    groups[key].push(tx);
  }
  return groups;
}

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
  const [amount, setAmount] = useState(transaction.amount);
  const [dateValue, setDateValue] = useState(() => {
    const d = new Date(transaction.date);
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 16);
  });
  const [deleting, setDeleting] = useState(false);
  const [saving, setSaving] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [txItems, setTxItems] = useState<TransactionItem[]>([]);
  const [loadingItems, setLoadingItems] = useState(true);

  const [allItems, setAllItems] = useState<Item[]>([]);
  const [itemSearch, setItemSearch] = useState("");
  const [itemSuggestions, setItemSuggestions] = useState<Item[]>([]);
  const [editedItems, setEditedItems] = useState<TransactionItem[]>([]);
  const [removedItemIds, setRemovedItemIds] = useState<string[]>([]);

  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [onClose]);

  useEffect(() => {
    async function fetchItems() {
      setLoadingItems(true);
      try {
        const [txItemsRes, allItemsRes] = await Promise.all([
          api.get(`/api/transactions/${transaction.id}/items`),
          api.get("/api/items"),
        ]);
        setTxItems(txItemsRes.data);
        setEditedItems(txItemsRes.data);
        setAllItems(allItemsRes.data);
      } catch {
        // no items
      } finally {
        setLoadingItems(false);
      }
    }
    fetchItems();
  }, [transaction.id]);
  useEffect(() => {
    if (itemSearch.length > 0) {
      setItemSuggestions(
        allItems
          .filter((i) =>
            i.name.toLowerCase().includes(itemSearch.toLowerCase()),
          )
          .slice(0, 6),
      );
    } else {
      setItemSuggestions([]);
    }
  }, [itemSearch, allItems]);
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
      // update transaction fields
      await api.patch(`/api/transactions/${transaction.id}`, {
        note: note || undefined,
        category_id: categoryId || undefined,
        amount:
          editedItems.length > 0
            ? editedItems.reduce((sum, i) => sum + i.amount * i.quantity, 0)
            : Number(amount),
        date: new Date(dateValue).toISOString(),
      });

      // remove deleted items
      await Promise.all(
        removedItemIds.map((id) => api.delete(`/api/transactions/items/${id}`)),
      );

      // update existing items
      await Promise.all(
        editedItems
          .filter((i) => i.id) // existing items
          .map((i) =>
            api.patch(`/api/transactions/items/${i.id}`, {
              amount: i.amount,
              quantity: i.quantity,
              remarks: i.remarks || undefined,
            }),
          ),
      );

      // add new items (no id yet)
      await Promise.all(
        editedItems
          .filter((i) => !i.id)
          .map((i) =>
            api.post(`/api/transactions/${transaction.id}/items`, {
              item_id: i.item_id,
              amount: i.amount,
              quantity: i.quantity,
              remarks: i.remarks || undefined,
            }),
          ),
      );

      showToast("success", "Transaction updated");
      window.dispatchEvent(new Event("transaction-added"));
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
          <button
            onClick={onClose}
            className="p-2 rounded-lg text-gray-400 hover:text-white transition-colors"
            style={{ background: "rgba(255,255,255,0.05)" }}
          >
            <X size={16} />
          </button>
        </div>

        {/* Amount */}
        <div className="text-center py-4">
          {editing ? (
            <div
              className="flex items-center justify-center gap-2 rounded-xl px-4 py-3 mx-auto w-56"
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
        {/* Items breakdown */}
        {!loadingItems && txItems.length > 0 && (
          <div
            className="rounded-2xl overflow-hidden"
            style={{
              background: "rgba(255,255,255,0.03)",
              border: "1px solid rgba(255,255,255,0.06)",
            }}
          >
            <div
              className="px-4 py-3 border-b"
              style={{ borderColor: "rgba(255,255,255,0.06)" }}
            >
              <p className="text-xs text-gray-500 uppercase tracking-wider font-semibold">
                Items
              </p>
            </div>
            <div className="flex flex-col">
              {txItems.map((item, i) => (
                <div
                  key={item.id}
                  className="flex items-start justify-between px-4 py-3 border-b last:border-0"
                  style={{ borderColor: "rgba(255,255,255,0.04)" }}
                >
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      {item.category_icon && (
                        <span className="text-sm">{item.category_icon}</span>
                      )}
                      <p className="text-white text-sm font-medium">
                        {item.item_name}
                      </p>
                      {item.quantity !== 1 && (
                        <span
                          className="text-xs px-1.5 py-0.5 rounded-full"
                          style={{
                            background: "rgba(255,255,255,0.06)",
                            color: "#9ca3af",
                          }}
                        >
                          x{item.quantity}
                        </span>
                      )}
                    </div>
                    {item.remarks && (
                      <p className="text-gray-600 text-xs mt-0.5 truncate">
                        {item.remarks}
                      </p>
                    )}
                  </div>
                  <div className="text-right flex-shrink-0 ml-4">
                    <p className="text-white text-sm font-semibold">
                      {formatCurrency(item.amount * item.quantity)}
                    </p>
                    {item.quantity !== 1 && (
                      <p className="text-gray-600 text-xs">
                        {formatCurrency(item.amount)} each
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>
            <div
              className="flex items-center justify-between px-4 py-3"
              style={{
                background: "rgba(108,99,255,0.06)",
                borderTop: "1px solid rgba(108,99,255,0.1)",
              }}
            >
              <span className="text-gray-400 text-sm font-medium">Total</span>
              <span className="text-white text-base font-bold">
                {formatCurrency(
                  txItems.reduce((sum, i) => sum + i.amount * i.quantity, 0),
                )}
              </span>
            </div>
          </div>
        )}
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
          {/* Items editing */}
          {editedItems.length > 0 || editing ? (
            <div>
              <p className="text-gray-500 text-xs uppercase tracking-wider font-semibold mb-3">
                Items
              </p>

              <div className="flex flex-col gap-2 mb-2">
                {editedItems.map((item) => (
                  <div
                    key={item.id ?? item.item_id}
                    className="rounded-xl p-3 flex flex-col gap-2"
                    style={{
                      background: "rgba(255,255,255,0.04)",
                      border: "1px solid rgba(255,255,255,0.06)",
                    }}
                  >
                    <div className="flex items-center justify-between">
                      <p className="text-white text-sm font-medium">
                        {item.item_name}
                      </p>
                      {editing && (
                        <button
                          onClick={() => {
                            if (item.id)
                              setRemovedItemIds((prev) => [...prev, item.id]);
                            setEditedItems((prev) =>
                              prev.filter(
                                (i) =>
                                  (i.id ?? i.item_id) !==
                                  (item.id ?? item.item_id),
                              ),
                            );
                          }}
                          className="text-gray-600 hover:text-red-400 transition-colors"
                        >
                          <Trash2 size={13} />
                        </button>
                      )}
                    </div>

                    {editing ? (
                      <div className="grid grid-cols-2 gap-2">
                        <div
                          className="flex items-center gap-1 rounded-lg px-3 py-2"
                          style={{ background: "rgba(255,255,255,0.05)" }}
                        >
                          <span className="text-gray-500 text-xs">₹</span>
                          <input
                            type="number"
                            value={item.amount}
                            onChange={(e) =>
                              setEditedItems((prev) =>
                                prev.map((i) =>
                                  (i.id ?? i.item_id) ===
                                  (item.id ?? item.item_id)
                                    ? {
                                        ...i,
                                        amount: parseFloat(e.target.value) || 0,
                                      }
                                    : i,
                                ),
                              )
                            }
                            className="bg-transparent text-white text-sm font-bold outline-none w-full"
                          />
                        </div>
                        <input
                          type="number"
                          placeholder="Qty"
                          value={item.quantity}
                          onChange={(e) =>
                            setEditedItems((prev) =>
                              prev.map((i) =>
                                (i.id ?? i.item_id) ===
                                (item.id ?? item.item_id)
                                  ? {
                                      ...i,
                                      quantity: parseFloat(e.target.value) || 1,
                                    }
                                  : i,
                              ),
                            )
                          }
                          className="rounded-lg px-3 py-2 text-white text-sm outline-none"
                          style={{ background: "rgba(255,255,255,0.05)" }}
                        />
                        <input
                          type="text"
                          placeholder="Remarks"
                          value={item.remarks ?? ""}
                          onChange={(e) =>
                            setEditedItems((prev) =>
                              prev.map((i) =>
                                (i.id ?? i.item_id) ===
                                (item.id ?? item.item_id)
                                  ? { ...i, remarks: e.target.value }
                                  : i,
                              ),
                            )
                          }
                          className="col-span-2 rounded-lg px-3 py-2 text-white text-sm outline-none placeholder-gray-700"
                          style={{ background: "rgba(255,255,255,0.05)" }}
                        />
                      </div>
                    ) : (
                      <div className="flex items-center justify-between">
                        <span className="text-gray-500 text-xs">
                          {item.quantity > 1
                            ? `${item.quantity} × ${formatCurrency(item.amount)}`
                            : ""}
                          {item.remarks ? ` · ${item.remarks}` : ""}
                        </span>
                        <span className="text-white text-sm font-semibold">
                          {formatCurrency(item.amount * item.quantity)}
                        </span>
                      </div>
                    )}
                  </div>
                ))}
              </div>

              {/* Add item in edit mode */}
              {editing && (
                <div className="relative">
                  <div
                    className="flex items-center gap-2 rounded-xl px-3 py-2.5"
                    style={{
                      background: "rgba(255,255,255,0.04)",
                      border: "1px dashed rgba(255,255,255,0.08)",
                    }}
                  >
                    <Plus size={14} className="text-gray-600" />
                    <input
                      type="text"
                      placeholder="Add item..."
                      value={itemSearch}
                      onChange={(e) => setItemSearch(e.target.value)}
                      className="bg-transparent text-white text-sm outline-none flex-1 placeholder-gray-600"
                      onKeyDown={async (e) => {
                        if (e.key === "Enter" && itemSearch.trim()) {
                          const match = allItems.find(
                            (i) =>
                              i.name.toLowerCase() === itemSearch.toLowerCase(),
                          );
                          const item =
                            match ??
                            (
                              await api.post("/api/items", {
                                name: itemSearch.trim(),
                              })
                            ).data;
                          setEditedItems((prev) => [
                            ...prev,
                            {
                              id: "",
                              transaction_id: transaction.id,
                              item_id: item.id,
                              item_name: item.name,
                              amount: item.last_price > 0 ? item.last_price : 0,
                              quantity: 1,
                              remarks: "",
                              created_at: new Date().toISOString(),
                            },
                          ]);
                          setItemSearch("");
                          setItemSuggestions([]);
                        }
                      }}
                    />
                  </div>

                  {itemSuggestions.length > 0 && (
                    <div
                      className="absolute top-full left-0 right-0 rounded-xl mt-1 overflow-hidden z-10"
                      style={{
                        background: "#1a1d2e",
                        border: "1px solid rgba(255,255,255,0.1)",
                      }}
                    >
                      {itemSuggestions.map((i) => (
                        <button
                          key={i.id}
                          onMouseDown={(e) => {
                            e.preventDefault();
                            setEditedItems((prev) => [
                              ...prev,
                              {
                                id: "",
                                transaction_id: transaction.id,
                                item_id: i.id,
                                item_name: i.name,
                                amount: i.last_price > 0 ? i.last_price : 0,
                                quantity: 1,
                                remarks: "",
                                created_at: new Date().toISOString(),
                              },
                            ]);
                            setItemSearch("");
                            setItemSuggestions([]);
                          }}
                          className="w-full text-left px-3 py-2.5 text-sm text-gray-300 hover:text-white hover:bg-white/5 transition-colors flex items-center justify-between"
                        >
                          <span>{i.name}</span>
                          {i.last_price > 0 && (
                            <span className="text-xs text-gray-500">
                              {formatCurrency(i.last_price)}
                            </span>
                          )}
                        </button>
                      ))}
                      {itemSearch.trim() &&
                        !allItems.find(
                          (i) =>
                            i.name.toLowerCase() === itemSearch.toLowerCase(),
                        ) && (
                          <button
                            onMouseDown={async (e) => {
                              e.preventDefault();
                              const res = await api.post("/api/items", {
                                name: itemSearch.trim(),
                              });
                              setEditedItems((prev) => [
                                ...prev,
                                {
                                  id: "",
                                  transaction_id: transaction.id,
                                  item_id: res.data.id,
                                  item_name: res.data.name,
                                  amount: 0,
                                  quantity: 1,
                                  remarks: "",
                                  created_at: new Date().toISOString(),
                                },
                              ]);
                              setItemSearch("");
                              setItemSuggestions([]);
                            }}
                            className="w-full text-left px-3 py-2.5 text-sm text-purple-400 hover:bg-white/5 border-t transition-colors"
                            style={{ borderColor: "rgba(255,255,255,0.06)" }}
                          >
                            + Create "{itemSearch.trim()}"
                          </button>
                        )}
                    </div>
                  )}
                </div>
              )}

              {/* Running total */}
              {editedItems.length > 0 && (
                <div
                  className="flex items-center justify-between rounded-xl px-4 py-3 mt-2"
                  style={{
                    background: "rgba(108,99,255,0.08)",
                    border: "1px solid rgba(108,99,255,0.15)",
                  }}
                >
                  <span className="text-gray-400 text-sm">Total</span>
                  <span className="text-white font-bold">
                    {formatCurrency(
                      editedItems.reduce(
                        (sum, i) => sum + i.amount * i.quantity,
                        0,
                      ),
                    )}
                  </span>
                </div>
              )}
            </div>
          ) : null}
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
              className="flex-1 py-3 rounded-xl text-gray-400 text-sm font-medium"
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

  function handleDeleted(id: string) {
    setTransactions((prev) => prev.filter((t) => t.id !== id));
  }

  function handleUpdated(tx: Transaction) {
    setTransactions((prev) => prev.map((t) => (t.id === tx.id ? tx : t)));
  }

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
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Transactions</h1>
          <p className="text-gray-500 text-sm mt-1">
            {loading ? "..." : `${filtered.length} transactions`}
          </p>
        </div>

        <div className="flex items-center gap-3">
          {/* Search */}
          <div
            className="flex items-center gap-2 px-4 py-2 rounded-xl"
            style={{ background: "rgba(255,255,255,0.05)" }}
          >
            <Search size={16} className="text-gray-500" />
            <input
              type="text"
              placeholder="Search transactions..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="bg-transparent text-white text-sm outline-none placeholder-gray-600 w-48"
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

          {/* Filters */}
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
      ) : filtered.length === 0 ? (
        <EmptyState
          icon="💸"
          message={
            search ? `No results for "${search}"` : "No transactions yet"
          }
          subMessage={
            search
              ? "Try a different search term"
              : "Tap the + button to add your first transaction"
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
                          {tx.item_count > 0 && (
                            <span className="text-xs text-gray-600">
                              · {tx.item_count} item
                              {tx.item_count !== 1 ? "s" : ""}
                            </span>
                          )}
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
