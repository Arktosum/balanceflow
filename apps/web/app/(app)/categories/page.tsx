"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { Category } from "@/lib/types";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { showToast } from "@/components/ui/Toast";
import { Plus, X, Trash2, Pencil } from "lucide-react";

const COLORS = [
  "#6C63FF",
  "#FF6B6B",
  "#4ECDC4",
  "#45B7D1",
  "#96CEB4",
  "#FFEAA7",
  "#DDA0DD",
  "#F7DC6F",
  "#82E0AA",
  "#F1948A",
  "#85C1E9",
  "#A0522D",
];

const ICONS = [
  "🍽️",
  "☕",
  "🚗",
  "🛒",
  "🛍️",
  "🎬",
  "💊",
  "💡",
  "🏠",
  "📚",
  "✈️",
  "📱",
  "💰",
  "💻",
  "🎁",
  "🔄",
  "📦",
  "🎮",
  "🏋️",
  "🐾",
  "🌿",
  "🎵",
  "💈",
  "⛽",
];

function CategoryFormModal({
  category,
  onClose,
  onSaved,
}: {
  category?: Category;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState(category?.name ?? "");
  const [icon, setIcon] = useState(category?.icon ?? "📦");
  const [color, setColor] = useState(category?.color ?? COLORS[0]);
  const [type, setType] = useState(category?.type ?? "both");
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
      if (category) {
        await api.patch(`/api/categories/${category.id}`, {
          name,
          icon,
          color,
          type,
        });
        showToast("success", "Category updated!");
      } else {
        await api.post("/api/categories", { name, icon, color, type });
        showToast("success", "Category created!");
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
            {category ? "Edit Category" : "New Category"}
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        {/* Preview */}
        <div className="flex items-center justify-center py-2">
          <div
            className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl"
            style={{ background: `${color}22`, border: `2px solid ${color}44` }}
          >
            {icon}
          </div>
        </div>

        {/* Name */}
        <div>
          <label className="text-xs text-gray-500 mb-1 block">Name</label>
          <input
            type="text"
            placeholder="e.g. Coffee"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none placeholder-gray-700"
            style={{ background: "rgba(255,255,255,0.06)" }}
          />
        </div>

        {/* Type */}
        <div>
          <label className="text-xs text-gray-500 mb-1 block">Type</label>
          <div className="flex gap-2">
            {(["expense", "income", "both"] as const).map((t) => (
              <button
                key={t}
                onClick={() => setType(t)}
                className="flex-1 py-2 rounded-xl text-sm font-medium capitalize transition-colors"
                style={
                  type === t
                    ? { background: "#6C63FF", color: "white" }
                    : { background: "rgba(255,255,255,0.05)", color: "#9ca3af" }
                }
              >
                {t}
              </button>
            ))}
          </div>
        </div>

        {/* Icon picker */}
        <div>
          <label className="text-xs text-gray-500 mb-2 block">Icon</label>
          <div className="flex flex-wrap gap-2">
            {ICONS.map((i) => (
              <button
                key={i}
                onClick={() => setIcon(i)}
                className="w-10 h-10 rounded-xl text-xl flex items-center justify-center transition-colors"
                style={{
                  background:
                    icon === i ? `${color}33` : "rgba(255,255,255,0.05)",
                  border:
                    icon === i ? `2px solid ${color}` : "2px solid transparent",
                }}
              >
                {i}
              </button>
            ))}
          </div>
        </div>

        {/* Color picker */}
        <div>
          <label className="text-xs text-gray-500 mb-2 block">Color</label>
          <div className="flex gap-2 flex-wrap">
            {COLORS.map((c) => (
              <button
                key={c}
                onClick={() => setColor(c)}
                className="w-8 h-8 rounded-full transition-transform hover:scale-110"
                style={{
                  background: c,
                  outline: color === c ? "3px solid white" : "none",
                  outlineOffset: "2px",
                }}
              />
            ))}
          </div>
        </div>

        <button
          onClick={handleSubmit}
          disabled={saving}
          className="w-full py-4 rounded-xl font-semibold text-white disabled:opacity-50"
          style={{ background: "linear-gradient(135deg, #6C63FF, #00D2FF)" }}
        >
          {saving ? "Saving..." : category ? "Save Changes" : "Create Category"}
        </button>
      </div>
    </div>
  );
}

export default function CategoriesPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Category | undefined>();
  const [confirmDelete, setConfirmDelete] = useState<Category | null>(null);
  const [deleting, setDeleting] = useState(false);

  async function fetchCategories() {
    setLoading(true);
    try {
      const res = await api.get("/api/categories");
      setCategories(res.data);
    } catch {
      showToast("error", "Could not load categories");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchCategories();
  }, []);

  async function handleDelete(category: Category) {
    setDeleting(true);
    try {
      await api.delete(`/api/categories/${category.id}`);
      showToast("success", `${category.name} deleted`);
      setConfirmDelete(null);
      fetchCategories();
    } catch (err: any) {
      showToast("error", err.response?.data?.error ?? "Failed to delete");
    } finally {
      setDeleting(false);
    }
  }

  const grouped = {
    expense: categories.filter((c) => c.type === "expense"),
    income: categories.filter((c) => c.type === "income"),
    both: categories.filter((c) => c.type === "both"),
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Categories</h1>
          <p className="text-gray-500 text-sm mt-1">
            {categories.length} categories
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
          New Category
        </button>
      </div>

      {loading ? (
        <div className="grid grid-cols-3 gap-3">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <Skeleton key={i} className="h-20" />
          ))}
        </div>
      ) : categories.length === 0 ? (
        <EmptyState icon="🏷️" message="No categories yet" />
      ) : (
        <div className="flex flex-col gap-6">
          {(["expense", "income", "both"] as const).map((type) =>
            grouped[type].length === 0 ? null : (
              <div key={type}>
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 capitalize">
                  {type === "both" ? "General" : type}
                </p>
                <div className="grid grid-cols-3 gap-3">
                  {grouped[type].map((category) => (
                    <Card key={category.id} className="flex items-center gap-3">
                      <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center text-xl flex-shrink-0"
                        style={{
                          background: `${category.color ?? "#6C63FF"}22`,
                        }}
                      >
                        {category.icon ?? "📦"}
                      </div>
                      <p
                        className="text-sm font-medium flex-1 truncate"
                        style={{ color: category.color ?? "white" }}
                      >
                        {category.name}
                      </p>
                      <div className="flex gap-1">
                        <button
                          onClick={() => {
                            setEditing(category);
                            setShowForm(true);
                          }}
                          className="p-1.5 rounded-lg text-gray-500 hover:text-white transition-colors"
                          style={{ background: "rgba(255,255,255,0.05)" }}
                        >
                          <Pencil size={12} />
                        </button>
                        <button
                          onClick={() => setConfirmDelete(category)}
                          className="p-1.5 rounded-lg text-gray-500 hover:text-red-400 transition-colors"
                          style={{ background: "rgba(255,255,255,0.05)" }}
                        >
                          <Trash2 size={12} />
                        </button>
                      </div>
                    </Card>
                  ))}
                </div>
              </div>
            ),
          )}
        </div>
      )}

      {showForm && (
        <CategoryFormModal
          category={editing}
          onClose={() => {
            setShowForm(false);
            setEditing(undefined);
          }}
          onSaved={fetchCategories}
        />
      )}

      {confirmDelete && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center"
          style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)" }}
        >
          <Card className="w-full max-w-sm p-6 flex flex-col gap-4">
            <h3 className="text-white font-bold text-lg">Delete Category?</h3>
            <p className="text-gray-400 text-sm">
              Are you sure you want to delete{" "}
              <span className="text-white font-medium">
                {confirmDelete.name}
              </span>
              ? Transactions using this category will be unaffected.
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
