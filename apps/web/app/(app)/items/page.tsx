"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { Item, Category } from "@/lib/types";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { showToast } from "@/components/ui/Toast";
import { formatCurrency } from "@/lib/utils";
import { Pencil, Trash2, X, TrendingUp } from "lucide-react";

function ItemFormModal({
  item,
  categories,
  onClose,
  onSaved,
}: {
  item: Item;
  categories: Category[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState(item.name);
  const [categoryId, setCategoryId] = useState(item.category_id ?? "");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [onClose]);

  async function handleSubmit() {
    if (!name.trim()) {
      showToast("error", "Name is required");
      return;
    }
    setSaving(true);
    try {
      await api.patch(`/api/items/${item.id}`, {
        name,
        category_id: categoryId || undefined,
      });
      showToast("success", "Item updated!");
      onSaved();
      onClose();
    } catch (err: any) {
      showToast("error", err.response?.data?.error ?? "Something went wrong");
    } finally {
      setSaving(false);
    }
  }

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
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold text-white">Edit Item</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        <div>
          <label className="text-xs text-gray-500 mb-1 block">Name</label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none"
            style={{ background: "rgba(255,255,255,0.06)" }}
          />
        </div>

        <div>
          <label className="text-xs text-gray-500 mb-1 block">
            Category (optional)
          </label>
          <select
            value={categoryId}
            onChange={(e) => setCategoryId(e.target.value)}
            className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none"
            style={{ background: "rgba(255,255,255,0.06)" }}
          >
            <option value="" style={{ background: "#1a1d2e" }}>
              None
            </option>
            {categories.map((c) => (
              <option key={c.id} value={c.id} style={{ background: "#1a1d2e" }}>
                {c.icon} {c.name}
              </option>
            ))}
          </select>
        </div>

        <button
          onClick={handleSubmit}
          disabled={saving}
          className="w-full py-4 rounded-xl font-semibold text-white disabled:opacity-50"
          style={{ background: "linear-gradient(135deg, #6C63FF, #00D2FF)" }}
        >
          {saving ? "Saving..." : "Save Changes"}
        </button>
      </div>
    </div>
  );
}

function ItemRow({
  item,
  onEdit,
  onDelete,
}: {
  item: Item;
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <Card className="flex items-center gap-4">
      {/* Avatar */}
      <div
        className="w-10 h-10 rounded-full flex items-center justify-center text-lg font-bold flex-shrink-0"
        style={{
          background: item.category_color
            ? `${item.category_color}22`
            : "rgba(108,99,255,0.15)",
          color: item.category_color ?? "#6C63FF",
        }}
      >
        {item.category_icon ?? item.name.charAt(0).toUpperCase()}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-white text-sm font-medium">{item.name}</p>
        <div className="flex items-center gap-3 mt-0.5">
          {item.category_name && (
            <span className="text-xs text-gray-500">{item.category_name}</span>
          )}
          <span className="text-xs text-gray-600">
            {item.usage_count} purchase{item.usage_count !== 1 ? "s" : ""}
          </span>
          {item.last_price > 0 && (
            <span className="text-xs text-gray-600">
              last {formatCurrency(item.last_price)}
            </span>
          )}
        </div>
      </div>

      {/* Actions */}
      <div className="flex gap-1 flex-shrink-0">
        <button
          onClick={onEdit}
          className="p-1.5 rounded-lg text-gray-500 hover:text-white transition-colors"
          style={{ background: "rgba(255,255,255,0.05)" }}
        >
          <Pencil size={13} />
        </button>
        <button
          onClick={onDelete}
          className="p-1.5 rounded-lg text-gray-500 hover:text-red-400 transition-colors"
          style={{ background: "rgba(255,255,255,0.05)" }}
        >
          <Trash2 size={13} />
        </button>
      </div>
    </Card>
  );
}

export default function ItemsPage() {
  const [items, setItems] = useState<Item[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<Item | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<Item | null>(null);
  const [deleting, setDeleting] = useState(false);

  async function fetchData() {
    setLoading(true);
    try {
      const [itemsRes, categoriesRes] = await Promise.all([
        api.get("/api/items"),
        api.get("/api/categories"),
      ]);
      setItems(itemsRes.data);
      setCategories(categoriesRes.data);
    } catch {
      showToast("error", "Could not load items");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchData();
  }, []);

  async function handleDelete(item: Item) {
    setDeleting(true);
    try {
      await api.delete(`/api/items/${item.id}`);
      showToast("success", `${item.name} deleted`);
      setConfirmDelete(null);
      fetchData();
    } catch (err: any) {
      showToast("error", err.response?.data?.error ?? "Failed to delete");
    } finally {
      setDeleting(false);
    }
  }

  const frequent = items.filter((i) => i.usage_count >= 3);
  const occasional = items.filter(
    (i) => i.usage_count > 0 && i.usage_count < 3,
  );
  const unused = items.filter((i) => i.usage_count === 0);

  const totalSpent = items.reduce(
    (sum, i) => sum + i.last_price * i.usage_count,
    0,
  );

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Items</h1>
          <p className="text-gray-500 text-sm mt-1">
            {items.length} items tracked
          </p>
        </div>
      </div>

      {/* Summary */}
      {!loading && items.length > 0 && (
        <div className="grid grid-cols-3 gap-4">
          <Card>
            <p className="text-gray-400 text-xs mb-2">Total Items</p>
            <p className="text-2xl font-bold text-white">{items.length}</p>
          </Card>
          <Card>
            <p className="text-gray-400 text-xs mb-2">Frequent</p>
            <p className="text-2xl font-bold text-purple-400">
              {frequent.length}
            </p>
          </Card>
          <Card>
            <div className="flex items-center gap-1 mb-2">
              <TrendingUp size={12} className="text-green-400" />
              <p className="text-gray-400 text-xs">Top Item</p>
            </div>
            <p className="text-sm font-bold text-white truncate">
              {items[0]?.name ?? "—"}
            </p>
          </Card>
        </div>
      )}

      {/* Items list */}
      {loading ? (
        <div className="flex flex-col gap-3">
          {[1, 2, 3, 4, 5].map((i) => (
            <Skeleton key={i} className="h-16" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          icon="🛍️"
          message="No items yet"
          subMessage="Items are created automatically when you add transactions"
        />
      ) : (
        <div className="flex flex-col gap-6">
          {frequent.length > 0 && (
            <div>
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                Frequent — 3+ purchases
              </p>
              <div className="flex flex-col gap-2">
                {frequent.map((item) => (
                  <ItemRow
                    key={item.id}
                    item={item}
                    onEdit={() => setEditing(item)}
                    onDelete={() => setConfirmDelete(item)}
                  />
                ))}
              </div>
            </div>
          )}

          {occasional.length > 0 && (
            <div>
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                Occasional
              </p>
              <div className="flex flex-col gap-2">
                {occasional.map((item) => (
                  <ItemRow
                    key={item.id}
                    item={item}
                    onEdit={() => setEditing(item)}
                    onDelete={() => setConfirmDelete(item)}
                  />
                ))}
              </div>
            </div>
          )}

          {unused.length > 0 && (
            <div>
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                Unused
              </p>
              <div className="flex flex-col gap-2">
                {unused.map((item) => (
                  <ItemRow
                    key={item.id}
                    item={item}
                    onEdit={() => setEditing(item)}
                    onDelete={() => setConfirmDelete(item)}
                  />
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Edit modal */}
      {editing && (
        <ItemFormModal
          item={editing}
          categories={categories}
          onClose={() => setEditing(null)}
          onSaved={fetchData}
        />
      )}

      {/* Delete confirmation */}
      {confirmDelete && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center"
          style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)" }}
        >
          <Card className="w-full max-w-sm p-6 flex flex-col gap-4">
            <h3 className="text-white font-bold text-lg">Delete Item?</h3>
            <p className="text-gray-400 text-sm">
              Are you sure you want to delete{" "}
              <span className="text-white font-medium">
                {confirmDelete.name}
              </span>
              ?
              {confirmDelete.usage_count > 0 && (
                <span className="text-yellow-400">
                  {" "}
                  This item has {confirmDelete.usage_count} transaction
                  {confirmDelete.usage_count !== 1 ? "s" : ""} and cannot be
                  deleted.
                </span>
              )}
            </p>
            <div className="flex gap-3 mt-2">
              <button
                onClick={() => setConfirmDelete(null)}
                className="flex-1 py-3 rounded-xl text-gray-400 text-sm font-medium"
                style={{ background: "rgba(255,255,255,0.05)" }}
              >
                Cancel
              </button>
              {confirmDelete.usage_count === 0 && (
                <button
                  onClick={() => handleDelete(confirmDelete)}
                  disabled={deleting}
                  className="flex-1 py-3 rounded-xl text-white text-sm font-semibold disabled:opacity-50"
                  style={{ background: "#ef4444" }}
                >
                  {deleting ? "Deleting..." : "Yes, Delete"}
                </button>
              )}
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
