"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { Account } from "@/lib/types";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { showToast } from "@/components/ui/Toast";
import { Plus, X, Trash2, Pencil } from "lucide-react";
import { formatCurrency } from "@/lib/utils";

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

const ACCOUNT_TYPES = ["cash", "bank", "wallet"];

function AccountFormModal({
  account,
  onClose,
  onSaved,
}: {
  account?: Account;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState(account?.name ?? "");
  const [type, setType] = useState(account?.type ?? "bank");
  const [balance, setBalance] = useState(account?.balance?.toString() ?? "0");
  const [color, setColor] = useState(account?.color ?? COLORS[0]);
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
      showToast("error", "Account name is required");
      return;
    }

    setSaving(true);
    try {
      if (account) {
        await api.patch(`/api/accounts/${account.id}`, { name, type, color });
        showToast("success", "Account updated!");
      } else {
        await api.post("/api/accounts", {
          name,
          type,
          balance: parseFloat(balance) || 0,
          color,
        });
        showToast("success", "Account created!");
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
        {/* Header */}
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold text-white">
            {account ? "Edit Account" : "New Account"}
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        {/* Name */}
        <div>
          <label className="text-xs text-gray-500 mb-1 block">
            Account Name
          </label>
          <input
            type="text"
            placeholder="e.g. HDFC Savings"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none placeholder-gray-700"
            style={{ background: "rgba(255,255,255,0.06)" }}
          />
        </div>

        {/* Type */}
        <div>
          <label className="text-xs text-gray-500 mb-1 block">
            Account Type
          </label>
          <div className="flex gap-2">
            {ACCOUNT_TYPES.map((t) => (
              <button
                key={t}
                onClick={() => setType(t as any)}
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

        {/* Opening balance — only for new accounts */}
        {!account && (
          <div>
            <label className="text-xs text-gray-500 mb-1 block">
              Opening Balance
            </label>
            <div
              className="flex items-center gap-2 rounded-xl px-4 py-3"
              style={{ background: "rgba(255,255,255,0.06)" }}
            >
              <span className="text-gray-400">₹</span>
              <input
                type="number"
                placeholder="0.00"
                value={balance}
                onChange={(e) => setBalance(e.target.value)}
                className="flex-1 bg-transparent text-white text-lg font-bold outline-none placeholder-gray-700"
              />
            </div>
          </div>
        )}

        {/* Color */}
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
                  outline: color === c ? `3px solid white` : "none",
                  outlineOffset: "2px",
                }}
              />
            ))}
          </div>
        </div>

        {/* Submit */}
        <button
          onClick={handleSubmit}
          disabled={saving}
          className="w-full py-4 rounded-xl font-semibold text-white transition-opacity disabled:opacity-50"
          style={{ background: "linear-gradient(135deg, #6C63FF, #00D2FF)" }}
        >
          {saving ? "Saving..." : account ? "Save Changes" : "Create Account"}
        </button>
      </div>
    </div>
  );
}

export default function AccountsPage() {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Account | undefined>();
  const [confirmDelete, setConfirmDelete] = useState<Account | null>(null);
  const [deleting, setDeleting] = useState(false);

  async function fetchAccounts() {
    setLoading(true);
    try {
      const res = await api.get("/api/accounts");
      setAccounts(res.data);
    } catch {
      showToast("error", "Could not load accounts");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchAccounts();
    window.addEventListener("transaction-added", fetchAccounts);
    return () => window.removeEventListener("transaction-added", fetchAccounts);
  }, []);

  async function handleDelete(account: Account) {
    setDeleting(true);
    try {
      await api.delete(`/api/accounts/${account.id}`);
      showToast("success", `${account.name} deleted`);
      setConfirmDelete(null);
      fetchAccounts();
    } catch (err: any) {
      showToast(
        "error",
        err.response?.data?.error ?? "Failed to delete account",
      );
    } finally {
      setDeleting(false);
    }
  }

  const totalBalance = accounts.reduce((sum, a) => sum + Number(a.balance), 0);

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Accounts</h1>
          <p className="text-gray-500 text-sm mt-1">
            {accounts.length} accounts
          </p>
        </div>
        <button
          onClick={() => {
            setEditing(undefined);
            setShowForm(true);
          }}
          className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium text-white transition-colors"
          style={{ background: "#6C63FF" }}
        >
          <Plus size={16} />
          New Account
        </button>
      </div>

      {/* Total balance */}
      {!loading && accounts.length > 0 && (
        <Card className="text-center py-6">
          <p className="text-gray-400 text-sm mb-2">Total Balance</p>
          <p className="text-4xl font-bold text-white">
            {formatCurrency(totalBalance)}
          </p>
        </Card>
      )}

      {/* Accounts grid */}
      {loading ? (
        <div className="grid grid-cols-2 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <Skeleton key={i} className="h-40" />
          ))}
        </div>
      ) : accounts.length === 0 ? (
        <EmptyState
          icon="💳"
          message="No accounts yet"
          subMessage="Add your first account to get started"
        />
      ) : (
        <div className="grid grid-cols-2 gap-4">
          {accounts.map((account) => (
            <Card key={account.id}>
              <div className="flex items-start justify-between mb-6">
                <div className="flex items-center gap-2">
                  <div
                    className="w-3 h-3 rounded-full"
                    style={{ backgroundColor: account.color ?? "#6C63FF" }}
                  />
                  <span className="text-gray-400 text-xs capitalize">
                    {account.type}
                  </span>
                </div>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => {
                      setEditing(account);
                      setShowForm(true);
                    }}
                    className="p-1.5 rounded-lg text-gray-500 hover:text-white transition-colors"
                    style={{ background: "rgba(255,255,255,0.05)" }}
                  >
                    <Pencil size={13} />
                  </button>
                  <button
                    onClick={() => setConfirmDelete(account)}
                    className="p-1.5 rounded-lg text-gray-500 hover:text-red-400 transition-colors"
                    style={{ background: "rgba(255,255,255,0.05)" }}
                  >
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>

              <p className="text-white font-semibold mb-1">{account.name}</p>
              <p
                className="text-2xl font-bold"
                style={{
                  color: Number(account.balance) >= 0 ? "white" : "#ef4444",
                }}
              >
                {formatCurrency(Number(account.balance))}
              </p>
            </Card>
          ))}
        </div>
      )}

      {/* Add/Edit modal */}
      {showForm && (
        <AccountFormModal
          account={editing}
          onClose={() => {
            setShowForm(false);
            setEditing(undefined);
          }}
          onSaved={fetchAccounts}
        />
      )}

      {/* Delete confirmation */}
      {confirmDelete && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center"
          style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)" }}
        >
          <Card className="w-full max-w-sm p-6 flex flex-col gap-4">
            <h3 className="text-white font-bold text-lg">Delete Account?</h3>
            <p className="text-gray-400 text-sm">
              Are you sure you want to delete{" "}
              <span className="text-white font-medium">
                {confirmDelete.name}
              </span>
              ? This action cannot be undone.
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
