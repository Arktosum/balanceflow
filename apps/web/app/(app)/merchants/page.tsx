"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { Merchant, Category } from "@/lib/types";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { showToast } from "@/components/ui/Toast";
import { Plus, X, Trash2, Pencil, Star } from "lucide-react";

function MerchantFormModal({
  merchant,
  categories,
  onClose,
  onSaved,
}: {
  merchant?: Merchant;
  categories: Category[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState(merchant?.name ?? "");
  const [categoryId, setCategoryId] = useState(
    merchant?.default_category_id ?? "",
  );
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
      if (merchant) {
        await api.patch(`/api/merchants/${merchant.id}`, {
          name,
          default_category_id: categoryId || undefined,
        });
        showToast("success", "Merchant updated!");
      } else {
        await api.post("/api/merchants", {
          name,
          default_category_id: categoryId || undefined,
        });
        showToast("success", "Merchant created!");
      }
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
          <h2 className="text-lg font-bold text-white">
            {merchant ? "Edit Merchant" : "New Merchant"}
          </h2>
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
            placeholder="e.g. Blue Tokai"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none placeholder-gray-700"
            style={{ background: "rgba(255,255,255,0.06)" }}
          />
        </div>

        <div>
          <label className="text-xs text-gray-500 mb-1 block">
            Default Category (optional)
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
          {saving ? "Saving..." : merchant ? "Save Changes" : "Create Merchant"}
        </button>
      </div>
    </div>
  );
}

export default function MerchantsPage() {
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Merchant | undefined>();
  const [confirmDelete, setConfirmDelete] = useState<Merchant | null>(null);
  const [deleting, setDeleting] = useState(false);

  async function fetchData() {
    setLoading(true);
    try {
      const [merchantsRes, categoriesRes] = await Promise.all([
        api.get("/api/merchants"),
        api.get("/api/categories"),
      ]);
      setMerchants(merchantsRes.data);
      setCategories(categoriesRes.data);
    } catch {
      showToast("error", "Could not load merchants");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchData();
  }, []);

  async function handleDelete(merchant: Merchant) {
    setDeleting(true);
    try {
      await api.delete(`/api/merchants/${merchant.id}`);
      showToast("success", `${merchant.name} deleted`);
      setConfirmDelete(null);
      fetchData();
    } catch (err: any) {
      showToast("error", err.response?.data?.error ?? "Failed to delete");
    } finally {
      setDeleting(false);
    }
  }

  const regulars = merchants.filter((m) => m.transaction_count >= 3);
  const occasional = merchants.filter((m) => m.transaction_count < 3);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Merchants</h1>
          <p className="text-gray-500 text-sm mt-1">
            {merchants.length} merchants
          </p>
        </div>
        <button
          onClick={() => {
            setEditing(undefined);
            setShowForm(true);
          }}
          className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium text-white"
          style={{ background: "#6C63FF" }}
        >
          <Plus size={16} />
          New Merchant
        </button>
      </div>

      {loading ? (
        <div className="flex flex-col gap-3">
          {[1, 2, 3, 4, 5].map((i) => (
            <Skeleton key={i} className="h-16" />
          ))}
        </div>
      ) : merchants.length === 0 ? (
        <EmptyState
          icon="🏪"
          message="No merchants yet"
          subMessage="They'll appear here as you log transactions"
        />
      ) : (
        <div className="flex flex-col gap-6">
          {regulars.length > 0 && (
            <div>
              <div className="flex items-center gap-2 mb-3">
                <Star size={14} className="text-yellow-400" />
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  Regulars
                </p>
              </div>
              <div className="flex flex-col gap-2">
                {regulars.map((merchant) => (
                  <MerchantRow
                    key={merchant.id}
                    merchant={merchant}
                    categories={categories}
                    onEdit={() => {
                      setEditing(merchant);
                      setShowForm(true);
                    }}
                    onDelete={() => setConfirmDelete(merchant)}
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
                {occasional.map((merchant) => (
                  <MerchantRow
                    key={merchant.id}
                    merchant={merchant}
                    categories={categories}
                    onEdit={() => {
                      setEditing(merchant);
                      setShowForm(true);
                    }}
                    onDelete={() => setConfirmDelete(merchant)}
                  />
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {showForm && (
        <MerchantFormModal
          merchant={editing}
          categories={categories}
          onClose={() => {
            setShowForm(false);
            setEditing(undefined);
          }}
          onSaved={fetchData}
        />
      )}

      {confirmDelete && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center"
          style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)" }}
        >
          <Card className="w-full max-w-sm p-6 flex flex-col gap-4">
            <h3 className="text-white font-bold text-lg">Delete Merchant?</h3>
            <p className="text-gray-400 text-sm">
              Are you sure you want to delete{" "}
              <span className="text-white font-medium">
                {confirmDelete.name}
              </span>
              ?
            </p>
            <div className="flex gap-3 mt-2">
              <button
                onClick={() => setConfirmDelete(null)}
                className="flex-1 py-3 rounded-xl text-gray-400 text-sm font-medium"
                style={{ background: "rgba(255,255,255,0.05)" }}
              >
                Cancel
              </button>
              <button
                onClick={() => handleDelete(confirmDelete)}
                disabled={deleting}
                className="flex-1 py-3 rounded-xl text-white text-sm font-semibold disabled:opacity-50"
                style={{ background: "#ef4444" }}
              >
                {deleting ? "Deleting..." : "Yes, Delete"}
              </button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}

function MerchantRow({
  merchant,
  categories,
  onEdit,
  onDelete,
}: {
  merchant: Merchant;
  categories: Category[];
  onEdit: () => void;
  onDelete: () => void;
}) {
  const category = categories.find(
    (c) => c.id === merchant.default_category_id,
  );

  return (
    <Card className="flex items-center gap-4">
      {/* Avatar */}
      <div
        className="w-10 h-10 rounded-full flex items-center justify-center text-lg font-bold flex-shrink-0"
        style={{ background: "rgba(108,99,255,0.15)", color: "#6C63FF" }}
      >
        {merchant.name.charAt(0).toUpperCase()}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-white text-sm font-medium">{merchant.name}</p>
        <div className="flex items-center gap-2 mt-0.5">
          {category && (
            <span className="text-xs text-gray-500">
              {category.icon} {category.name}
            </span>
          )}
          <span className="text-xs text-gray-600">
            {merchant.transaction_count} transaction
            {merchant.transaction_count !== 1 ? "s" : ""}
          </span>
        </div>
      </div>

      {/* Actions */}
      <div className="flex gap-1">
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
