"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { Debt } from "@/lib/types";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { showToast } from "@/components/ui/Toast";
import { formatCurrency } from "@/lib/utils";
import { Check, ArrowDownLeft, ArrowUpRight } from "lucide-react";

function SettleConfirmModal({
  debt,
  onClose,
  onSettled,
}: {
  debt: Debt;
  onClose: () => void;
  onSettled: () => void;
}) {
  const [settling, setSettling] = useState(false);

  async function handleSettle() {
    setSettling(true);
    try {
      await api.patch(`/api/debts/${debt.id}/settle`);
      showToast("success", "Debt settled!");
      onSettled();
      onClose();
      window.dispatchEvent(new Event("transaction-added"));
    } catch {
      showToast("error", "Failed to settle debt");
    } finally {
      setSettling(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)" }}
    >
      <Card className="w-full max-w-sm p-6 flex flex-col gap-4">
        <h3 className="text-white font-bold text-lg">Settle Debt?</h3>
        <div
          className="rounded-xl p-4"
          style={{ background: "rgba(255,255,255,0.04)" }}
        >
          <p className="text-gray-400 text-sm mb-1">
            {debt.direction === "i_owe" ? "You owe" : "They owe you"}
          </p>
          <p className="text-white font-bold text-xl">
            {formatCurrency(debt.amount)}
          </p>
          <p className="text-gray-500 text-sm mt-1">{debt.person_name}</p>
        </div>
        <p className="text-gray-400 text-sm">
          This will mark the transaction as completed and{" "}
          {debt.direction === "i_owe"
            ? "deduct from your account balance."
            : "add to your account balance."}
        </p>
        <div className="flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 py-3 rounded-xl text-gray-400 text-sm font-medium"
            style={{ background: "rgba(255,255,255,0.05)" }}
          >
            Cancel
          </button>
          <button
            onClick={handleSettle}
            disabled={settling}
            className="flex-1 py-3 rounded-xl text-white text-sm font-semibold disabled:opacity-50 flex items-center justify-center gap-2"
            style={{ background: "#22c55e" }}
          >
            <Check size={16} />
            {settling ? "Settling..." : "Mark Settled"}
          </button>
        </div>
      </Card>
    </div>
  );
}

function DebtCard({ debt, onSettle }: { debt: Debt; onSettle: () => void }) {
  const isIOwe = debt.direction === "i_owe";

  return (
    <Card className="flex items-center gap-4">
      {/* Direction icon */}
      <div
        className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0"
        style={{
          background: isIOwe ? "rgba(239,68,68,0.1)" : "rgba(34,197,94,0.1)",
        }}
      >
        {isIOwe ? (
          <ArrowUpRight size={18} className="text-red-400" />
        ) : (
          <ArrowDownLeft size={18} className="text-green-400" />
        )}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-white text-sm font-medium">{debt.person_name}</p>
        <div className="flex items-center gap-2 mt-0.5">
          <span
            className="text-xs px-2 py-0.5 rounded-full"
            style={{
              background: isIOwe
                ? "rgba(239,68,68,0.1)"
                : "rgba(34,197,94,0.1)",
              color: isIOwe ? "#ef4444" : "#22c55e",
            }}
          >
            {isIOwe ? "I owe" : "They owe me"}
          </span>
          {debt.note && (
            <span className="text-gray-600 text-xs truncate">{debt.note}</span>
          )}
        </div>
        <p className="text-gray-600 text-xs mt-0.5">
          {new Date(debt.date).toLocaleDateString("en-IN", {
            day: "numeric",
            month: "short",
            year: "numeric",
          })}
        </p>
      </div>

      {/* Amount + settle */}
      <div className="flex items-center gap-3 flex-shrink-0">
        <p
          className="text-lg font-bold"
          style={{ color: isIOwe ? "#ef4444" : "#22c55e" }}
        >
          {isIOwe ? "-" : "+"}
          {formatCurrency(debt.amount)}
        </p>
        <button
          onClick={onSettle}
          className="px-3 py-1.5 rounded-xl text-xs font-medium flex items-center gap-1 transition-colors"
          style={{ background: "rgba(34,197,94,0.1)", color: "#22c55e" }}
        >
          <Check size={12} />
          Settle
        </button>
      </div>
    </Card>
  );
}

export default function DebtsPage() {
  const [debts, setDebts] = useState<Debt[]>([]);
  const [settledDebts, setSettledDebts] = useState<Debt[]>([]);
  const [loading, setLoading] = useState(true);
  const [settling, setSettling] = useState<Debt | null>(null);
  const [showSettled, setShowSettled] = useState(false);

  async function fetchDebts() {
    setLoading(true);
    try {
      const [activeRes, settledRes] = await Promise.all([
        api.get("/api/debts"),
        api.get("/api/debts?settled=true"),
      ]);
      setDebts(activeRes.data);
      setSettledDebts(settledRes.data);
    } catch {
      showToast("error", "Could not load debts");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchDebts();
  }, []);

  const iOwe = debts.filter((d) => d.direction === "i_owe");
  const theyOwe = debts.filter((d) => d.direction === "they_owe");
  const totalIOwe = iOwe.reduce((sum, d) => sum + Number(d.amount), 0);
  const totalTheyOwe = theyOwe.reduce((sum, d) => sum + Number(d.amount), 0);

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-white">Debts</h1>
        <p className="text-gray-500 text-sm mt-1">Pending settlements</p>
      </div>

      {/* Summary cards */}
      {!loading && debts.length > 0 && (
        <div className="grid grid-cols-2 gap-4">
          <Card>
            <div className="flex items-center gap-2 mb-3">
              <ArrowUpRight size={16} className="text-red-400" />
              <p className="text-gray-400 text-sm">I Owe</p>
            </div>
            <p className="text-2xl font-bold text-red-400">
              {formatCurrency(totalIOwe)}
            </p>
            <p className="text-gray-600 text-xs mt-1">{iOwe.length} pending</p>
          </Card>
          <Card>
            <div className="flex items-center gap-2 mb-3">
              <ArrowDownLeft size={16} className="text-green-400" />
              <p className="text-gray-400 text-sm">They Owe Me</p>
            </div>
            <p className="text-2xl font-bold text-green-400">
              {formatCurrency(totalTheyOwe)}
            </p>
            <p className="text-gray-600 text-xs mt-1">
              {theyOwe.length} pending
            </p>
          </Card>
        </div>
      )}

      {/* Active debts */}
      {loading ? (
        <div className="flex flex-col gap-3">
          {[1, 2, 3].map((i) => (
            <Skeleton key={i} className="h-20" />
          ))}
        </div>
      ) : debts.length === 0 ? (
        <EmptyState
          icon="🤝"
          message="No pending debts"
          subMessage="All settled up!"
        />
      ) : (
        <div className="flex flex-col gap-6">
          {iOwe.length > 0 && (
            <div>
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                I Owe
              </p>
              <div className="flex flex-col gap-2">
                {iOwe.map((debt) => (
                  <DebtCard
                    key={debt.id}
                    debt={debt}
                    onSettle={() => setSettling(debt)}
                  />
                ))}
              </div>
            </div>
          )}

          {theyOwe.length > 0 && (
            <div>
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                They Owe Me
              </p>
              <div className="flex flex-col gap-2">
                {theyOwe.map((debt) => (
                  <DebtCard
                    key={debt.id}
                    debt={debt}
                    onSettle={() => setSettling(debt)}
                  />
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Settled debts toggle */}
      {settledDebts.length > 0 && (
        <div>
          <button
            onClick={() => setShowSettled(!showSettled)}
            className="text-sm text-gray-500 hover:text-gray-300 transition-colors"
          >
            {showSettled ? "▲ Hide" : "▼ Show"} settled debts (
            {settledDebts.length})
          </button>

          {showSettled && (
            <div className="flex flex-col gap-2 mt-3">
              {settledDebts.map((debt) => (
                <Card
                  key={debt.id}
                  className="flex items-center gap-4 opacity-50"
                >
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0"
                    style={{ background: "rgba(255,255,255,0.05)" }}
                  >
                    <Check size={18} className="text-gray-500" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-gray-400 text-sm font-medium">
                      {debt.person_name}
                    </p>
                    <p className="text-gray-600 text-xs">
                      Settled{" "}
                      {new Date(debt.settled_at!).toLocaleDateString("en-IN", {
                        day: "numeric",
                        month: "short",
                        year: "numeric",
                      })}
                    </p>
                  </div>
                  <p className="text-gray-500 text-sm font-bold">
                    {formatCurrency(debt.amount)}
                  </p>
                </Card>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Settle confirmation */}
      {settling && (
        <SettleConfirmModal
          debt={settling}
          onClose={() => setSettling(null)}
          onSettled={fetchDebts}
        />
      )}
    </div>
  );
}
