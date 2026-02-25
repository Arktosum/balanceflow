"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { showToast } from "@/components/ui/Toast";
import { formatCurrency, formatDate, formatTime } from "@/lib/utils";
import {
  Item,
  Transaction,
  Category,
  TransactionItem,
  Account,
  Merchant,
} from "@/lib/types";
import { Trash2, X, Plus } from "lucide-react";

// ─── Item row ────────────────────────────────────────────────────────────────
function ItemRow({
  item,
  editing,
  onUpdate,
  onRemove,
}: {
  item: TransactionItem;
  editing: boolean;
  onUpdate: (field: keyof TransactionItem, value: any) => void;
  onRemove: () => void;
}) {
  return (
    <div
      className="rounded-2xl p-4 flex flex-col gap-3"
      style={{
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.06)",
      }}
    >
      <div className="flex items-center justify-between">
        <p className="text-white text-sm font-semibold">{item.item_name}</p>
        <div className="flex items-center gap-2">
          <p className="text-white text-sm font-bold">
            {formatCurrency(item.amount * item.quantity)}
          </p>
          {editing && (
            <button
              onClick={onRemove}
              className="text-gray-600 hover:text-red-400 transition-colors ml-1"
            >
              <Trash2 size={13} />
            </button>
          )}
        </div>
      </div>

      {editing ? (
        <div className="grid grid-cols-3 gap-2">
          <div
            className="col-span-1 flex items-center gap-1 rounded-xl px-3 py-2"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <span className="text-gray-500 text-xs">₹</span>
            <input
              type="number"
              value={item.amount}
              onChange={(e) =>
                onUpdate("amount", parseFloat(e.target.value) || 0)
              }
              className="bg-transparent text-white text-sm font-bold outline-none w-full"
            />
          </div>
          <div
            className="col-span-1 flex items-center gap-1 rounded-xl px-3 py-2"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <span className="text-gray-500 text-xs">×</span>
            <input
              type="number"
              value={item.quantity}
              onChange={(e) =>
                onUpdate("quantity", parseFloat(e.target.value) || 1)
              }
              className="bg-transparent text-white text-sm outline-none w-full"
            />
          </div>
          <input
            type="text"
            placeholder="Note"
            value={item.remarks ?? ""}
            onChange={(e) => onUpdate("remarks", e.target.value)}
            className="col-span-1 rounded-xl px-3 py-2 text-white text-xs outline-none placeholder-gray-700"
            style={{ background: "rgba(255,255,255,0.06)" }}
          />
        </div>
      ) : (
        <div className="flex items-center gap-3">
          {item.quantity > 1 && (
            <span
              className="text-xs px-2 py-0.5 rounded-full"
              style={{ background: "rgba(255,255,255,0.06)", color: "#9ca3af" }}
            >
              × {item.quantity}
            </span>
          )}
          {item.quantity > 1 && (
            <span className="text-gray-600 text-xs">
              {formatCurrency(item.amount)} each
            </span>
          )}
          {item.remarks && (
            <span className="text-gray-500 text-xs">{item.remarks}</span>
          )}
        </div>
      )}
    </div>
  );
}

// ─── Main modal ───────────────────────────────────────────────────────────────
export default function TransactionModal({
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
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);

  // Editable fields
  const [note, setNote] = useState(transaction.note ?? "");
  const [categoryId, setCategoryId] = useState(transaction.category_id ?? "");
  const [accountId, setAccountId] = useState(transaction.account_id ?? "");
  const [merchantName, setMerchantName] = useState(
    transaction.merchant_name ?? "",
  );
  const [dateValue, setDateValue] = useState(() => {
    const d = new Date(transaction.date);
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 16);
  });

  // Data
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [filteredMerchants, setFilteredMerchants] = useState<Merchant[]>([]);

  // Items
  const [loadingItems, setLoadingItems] = useState(true);
  const [allItems, setAllItems] = useState<Item[]>([]);
  const [editedItems, setEditedItems] = useState<TransactionItem[]>([]);
  const [removedItemIds, setRemovedItemIds] = useState<string[]>([]);
  const [itemSearch, setItemSearch] = useState("");
  const [itemSuggestions, setItemSuggestions] = useState<Item[]>([]);

  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [onClose]);

  useEffect(() => {
    async function load() {
      setLoadingItems(true);
      try {
        const [txItemsRes, allItemsRes, accountsRes, merchantsRes] =
          await Promise.all([
            api.get(`/api/transactions/${transaction.id}/items`),
            api.get("/api/items"),
            api.get("/api/accounts"),
            api.get("/api/merchants"),
          ]);
        setEditedItems(txItemsRes.data);
        setAllItems(allItemsRes.data);
        setAccounts(accountsRes.data);
        setMerchants(merchantsRes.data);
      } catch {
      } finally {
        setLoadingItems(false);
      }
    }
    load();
  }, [transaction.id]);

  useEffect(() => {
    if (merchantName.length > 0) {
      setFilteredMerchants(
        merchants
          .filter((m) =>
            m.name.toLowerCase().includes(merchantName.toLowerCase()),
          )
          .slice(0, 5),
      );
    } else {
      setFilteredMerchants([]);
    }
  }, [merchantName, merchants]);

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

  function addItem(item: Item) {
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

  function updateItem(key: string, field: keyof TransactionItem, value: any) {
    setEditedItems((prev) =>
      prev.map((i) =>
        (i.id || i.item_id) === key ? { ...i, [field]: value } : i,
      ),
    );
  }

  function removeItem(item: TransactionItem) {
    if (item.id) setRemovedItemIds((prev) => [...prev, item.id]);
    setEditedItems((prev) =>
      prev.filter((i) => (i.id || i.item_id) !== (item.id || item.item_id)),
    );
  }

  async function handleSave() {
    setSaving(true);
    try {
      // Resolve merchant
      let merchantId: string | null = null;
      if (merchantName.trim()) {
        const existing = merchants.find(
          (m) => m.name.toLowerCase() === merchantName.trim().toLowerCase(),
        );
        if (existing) {
          merchantId = existing.id;
        } else {
          const res = await api.post("/api/merchants", {
            name: merchantName.trim(),
          });
          merchantId = res.data.id;
        }
      }

      const derivedAmount =
        editedItems.length > 0
          ? editedItems.reduce((sum, i) => sum + i.amount * i.quantity, 0)
          : transaction.amount;

      await api.patch(`/api/transactions/${transaction.id}`, {
        note: note || undefined,
        category_id: categoryId || undefined,
        account_id: accountId || undefined,
        merchant_id: merchantId,
        amount: derivedAmount,
        date: new Date(dateValue).toISOString(),
      });

      await Promise.all(
        removedItemIds.map((id) => api.delete(`/api/transactions/items/${id}`)),
      );
      await Promise.all(
        editedItems
          .filter((i) => i.id)
          .map((i) =>
            api.patch(`/api/transactions/items/${i.id}`, {
              amount: i.amount,
              quantity: i.quantity,
              remarks: i.remarks || undefined,
            }),
          ),
      );
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
      showToast("error", "Failed to update");
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    setDeleting(true);
    try {
      await api.delete(`/api/transactions/${transaction.id}`);
      showToast("success", "Transaction deleted");
      onDeleted(transaction.id);
      window.dispatchEvent(new Event("transaction-added"));
      onClose();
    } catch {
      showToast("error", "Failed to delete");
    } finally {
      setDeleting(false);
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

  const derivedTotal = editedItems.reduce(
    (sum, i) => sum + i.amount * i.quantity,
    0,
  );
  const displayAmount =
    editedItems.length > 0 ? derivedTotal : transaction.amount;
  const selectedCategory = categories.find((c) => c.id === categoryId);

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-6"
      style={{ background: "rgba(0,0,0,0.75)", backdropFilter: "blur(12px)" }}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        className="w-full max-w-xl flex flex-col rounded-3xl overflow-hidden"
        style={{
          background: "rgba(13,15,23,0.99)",
          border: "1px solid rgba(255,255,255,0.07)",
          height: "88vh",
        }}
      >
        {/* ── Header ── */}
        <div
          className="flex items-center justify-between px-6 py-4 flex-shrink-0"
          style={{ borderBottom: "1px solid rgba(255,255,255,0.05)" }}
        >
          <div className="flex items-center gap-3">
            <div
              className="w-8 h-8 rounded-xl flex items-center justify-center text-base"
              style={{
                background: transaction.category_color
                  ? `${transaction.category_color}22`
                  : "rgba(108,99,255,0.15)",
              }}
            >
              {transaction.category_icon ??
                (transaction.type === "transfer"
                  ? "🔄"
                  : transaction.type === "income"
                    ? "�"
                    : "💸")}
            </div>
            <div>
              <p className="text-white text-sm font-semibold">
                {transaction.merchant_name ?? transaction.note ?? "Transaction"}
              </p>
              <p className="text-gray-500 text-xs capitalize">
                {transaction.type}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-gray-500 hover:text-white transition-colors"
            style={{ background: "rgba(255,255,255,0.05)" }}
          >
            <X size={16} />
          </button>
        </div>

        {/* ── Scrollable body ── */}
        <div className="flex-1 overflow-y-auto">
          {/* Amount hero */}
          <div
            className="px-6 py-8 text-center"
            style={{ borderBottom: "1px solid rgba(255,255,255,0.05)" }}
          >
            <p
              className="text-6xl font-bold tracking-tight"
              style={{ color: amountColor }}
            >
              {amountPrefix}
              {formatCurrency(displayAmount)}
            </p>
            <div className="flex items-center justify-center gap-3 mt-3">
              <span className="text-gray-500 text-sm">
                {transaction.account_name}
              </span>
              {transaction.to_account_name && (
                <>
                  <span className="text-gray-700">→</span>
                  <span className="text-gray-500 text-sm">
                    {transaction.to_account_name}
                  </span>
                </>
              )}
              <span
                className="text-xs px-2 py-0.5 rounded-full font-medium"
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
            <p className="text-gray-600 text-xs mt-2">
              {formatDate(transaction.date)} at {formatTime(transaction.date)}
            </p>
          </div>

          {/* Items */}
          {!loadingItems && (editedItems.length > 0 || editing) && (
            <div
              className="px-6 py-5"
              style={{ borderBottom: "1px solid rgba(255,255,255,0.05)" }}
            >
              <div className="flex items-center justify-between mb-4">
                <p className="text-xs text-gray-500 uppercase tracking-wider font-semibold">
                  Items
                </p>
                {editedItems.length > 0 && (
                  <span className="text-xs text-gray-600">
                    {editedItems.length} item
                    {editedItems.length !== 1 ? "s" : ""}
                  </span>
                )}
              </div>

              <div className="flex flex-col gap-2">
                {editedItems.map((item) => (
                  <ItemRow
                    key={item.id || item.item_id}
                    item={item}
                    editing={editing}
                    onUpdate={(field, value) =>
                      updateItem(item.id || item.item_id, field, value)
                    }
                    onRemove={() => removeItem(item)}
                  />
                ))}
              </div>

              {editing && (
                <div className="relative mt-3">
                  <div
                    className="flex items-center gap-2 rounded-2xl px-4 py-3"
                    style={{
                      background: "rgba(255,255,255,0.03)",
                      border: "1px dashed rgba(255,255,255,0.1)",
                    }}
                  >
                    <Plus size={14} className="text-gray-600 flex-shrink-0" />
                    <input
                      type="text"
                      placeholder="Add item..."
                      value={itemSearch}
                      onChange={(e) => setItemSearch(e.target.value)}
                      className="bg-transparent text-white text-sm outline-none flex-1 placeholder-gray-700"
                      onKeyDown={async (e) => {
                        if (e.key === "Enter" && itemSearch.trim()) {
                          const match = allItems.find(
                            (i) =>
                              i.name.toLowerCase() === itemSearch.toLowerCase(),
                          );
                          if (match) {
                            addItem(match);
                          } else {
                            const res = await api.post("/api/items", {
                              name: itemSearch.trim(),
                            });
                            addItem({
                              ...res.data,
                              last_price: 0,
                              usage_count: 0,
                            });
                          }
                        }
                      }}
                    />
                  </div>
                  {itemSuggestions.length > 0 && (
                    <div
                      className="absolute top-full left-0 right-0 rounded-2xl mt-1 overflow-hidden z-20"
                      style={{
                        background: "#0f1119",
                        border: "1px solid rgba(255,255,255,0.1)",
                      }}
                    >
                      {itemSuggestions.map((i) => (
                        <button
                          key={i.id}
                          onMouseDown={(e) => {
                            e.preventDefault();
                            addItem(i);
                          }}
                          className="w-full text-left px-4 py-3 text-sm text-gray-300 hover:text-white hover:bg-white/5 transition-colors flex items-center justify-between"
                        >
                          <span>{i.name}</span>
                          {i.last_price > 0 && (
                            <span className="text-xs text-gray-600">
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
                              addItem({
                                ...res.data,
                                last_price: 0,
                                usage_count: 0,
                              });
                            }}
                            className="w-full text-left px-4 py-3 text-sm text-purple-400 hover:bg-white/5 border-t transition-colors"
                            style={{ borderColor: "rgba(255,255,255,0.06)" }}
                          >
                            + Create "{itemSearch.trim()}"
                          </button>
                        )}
                    </div>
                  )}
                </div>
              )}

              {editedItems.length > 0 && (
                <div
                  className="flex items-center justify-between rounded-2xl px-4 py-3 mt-3"
                  style={{
                    background: "rgba(108,99,255,0.07)",
                    border: "1px solid rgba(108,99,255,0.12)",
                  }}
                >
                  <span className="text-gray-400 text-sm">Total</span>
                  <span className="text-white font-bold">
                    {formatCurrency(derivedTotal)}
                  </span>
                </div>
              )}
            </div>
          )}

          {/* Details grid */}
          <div className="px-6 py-5">
            <p className="text-xs text-gray-500 uppercase tracking-wider font-semibold mb-4">
              Details
            </p>

            <div className="grid grid-cols-2 gap-x-6 gap-y-5">
              {/* Date */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-600 uppercase tracking-wider font-semibold">
                  Date
                </span>
                {editing ? (
                  <input
                    type="datetime-local"
                    value={dateValue}
                    onChange={(e) => setDateValue(e.target.value)}
                    className="rounded-xl px-3 py-2 text-white text-sm outline-none"
                    style={{
                      background: "rgba(255,255,255,0.06)",
                      colorScheme: "dark",
                    }}
                  />
                ) : (
                  <div>
                    <p className="text-white text-sm font-medium">
                      {formatDate(transaction.date)}
                    </p>
                    <p className="text-gray-600 text-xs">
                      {formatTime(transaction.date)}
                    </p>
                  </div>
                )}
              </div>

              {/* Category */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-600 uppercase tracking-wider font-semibold">
                  Category
                </span>
                {editing ? (
                  <select
                    value={categoryId}
                    onChange={(e) => setCategoryId(e.target.value)}
                    className="rounded-xl px-3 py-2 text-white text-sm outline-none"
                    style={{ background: "rgba(255,255,255,0.06)" }}
                  >
                    <option value="" style={{ background: "#0f1119" }}>
                      None
                    </option>
                    {categories.map((c) => (
                      <option
                        key={c.id}
                        value={c.id}
                        style={{ background: "#0f1119" }}
                      >
                        {c.icon} {c.name}
                      </option>
                    ))}
                  </select>
                ) : (
                  <p className="text-white text-sm font-medium">
                    {selectedCategory
                      ? `${selectedCategory.icon} ${selectedCategory.name}`
                      : transaction.category_name
                        ? `${transaction.category_icon ?? ""} ${transaction.category_name}`
                        : "—"}
                  </p>
                )}
              </div>

              {/* Account */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-600 uppercase tracking-wider font-semibold">
                  Account
                </span>
                {editing ? (
                  <select
                    value={accountId}
                    onChange={(e) => setAccountId(e.target.value)}
                    className="rounded-xl px-3 py-2 text-white text-sm outline-none"
                    style={{ background: "rgba(255,255,255,0.06)" }}
                  >
                    {accounts.map((a) => (
                      <option
                        key={a.id}
                        value={a.id}
                        style={{ background: "#0f1119" }}
                      >
                        {a.name}
                      </option>
                    ))}
                  </select>
                ) : (
                  <p className="text-white text-sm font-medium">
                    {transaction.account_name}
                  </p>
                )}
              </div>

              {/* Merchant */}
              <div className="flex flex-col gap-1">
                <span className="text-xs text-gray-600 uppercase tracking-wider font-semibold">
                  Merchant
                </span>
                {editing ? (
                  <div className="relative">
                    <input
                      type="text"
                      value={merchantName}
                      onChange={(e) => setMerchantName(e.target.value)}
                      placeholder="e.g. Swiggy"
                      className="w-full rounded-xl px-3 py-2 text-white text-sm outline-none placeholder-gray-700"
                      style={{ background: "rgba(255,255,255,0.06)" }}
                    />
                    {filteredMerchants.length > 0 && (
                      <div
                        className="absolute top-full left-0 right-0 rounded-xl mt-1 overflow-hidden z-20"
                        style={{
                          background: "#0f1119",
                          border: "1px solid rgba(255,255,255,0.1)",
                        }}
                      >
                        {filteredMerchants.map((m) => (
                          <button
                            key={m.id}
                            onMouseDown={(e) => {
                              e.preventDefault();
                              setMerchantName(m.name);
                              setFilteredMerchants([]);
                            }}
                            className="w-full text-left px-3 py-2.5 text-sm text-gray-300 hover:text-white hover:bg-white/5 transition-colors"
                          >
                            {m.name}
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                ) : (
                  <p className="text-white text-sm font-medium">
                    {transaction.merchant_name ?? "—"}
                  </p>
                )}
              </div>

              {/* Note — full width */}
              <div className="col-span-2 flex flex-col gap-1">
                <span className="text-xs text-gray-600 uppercase tracking-wider font-semibold">
                  Note
                </span>
                {editing ? (
                  <input
                    type="text"
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                    placeholder="Add a note..."
                    className="w-full rounded-xl px-3 py-2 text-white text-sm outline-none placeholder-gray-700"
                    style={{ background: "rgba(255,255,255,0.06)" }}
                  />
                ) : (
                  <p className="text-white text-sm font-medium">
                    {note || "—"}
                  </p>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* ── Footer ── */}
        <div
          className="px-6 py-4 flex-shrink-0"
          style={{ borderTop: "1px solid rgba(255,255,255,0.05)" }}
        >
          {confirmDelete ? (
            <div className="flex flex-col gap-3">
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
          ) : editing ? (
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
                style={{
                  background: "linear-gradient(135deg, #6C63FF, #00D2FF)",
                }}
              >
                {saving ? "Saving..." : "Save Changes"}
              </button>
            </div>
          ) : (
            <div className="flex gap-3">
              <button
                onClick={() => setEditing(true)}
                className="flex-1 py-3 rounded-xl text-sm font-medium"
                style={{ background: "rgba(108,99,255,0.1)", color: "#6C63FF" }}
              >
                Edit Transaction
              </button>
              <button
                onClick={() => setConfirmDelete(true)}
                className="py-3 px-4 rounded-xl text-sm font-medium"
                style={{ background: "rgba(239,68,68,0.08)", color: "#ef4444" }}
              >
                <Trash2 size={16} />
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
