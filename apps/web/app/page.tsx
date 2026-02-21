"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { Account, AnalyticsSummary } from "@/lib/types";
import Card from "@/components/ui/Card";
import EmptyState from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { TrendingUp, TrendingDown, ArrowLeftRight } from "lucide-react";

function formatCurrency(amount: number) {
  return `₹${Math.abs(amount).toLocaleString("en-IN", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

type Period = "day" | "week" | "month" | "year";

export default function DashboardPage() {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [summary, setSummary] = useState<AnalyticsSummary | null>(null);
  const [period, setPeriod] = useState<Period>("month");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchData();
  }, [period]);

  async function fetchData() {
    setLoading(true);
    try {
      const [accountsRes, summaryRes] = await Promise.all([
        api.get("/api/accounts"),
        api.get(`/api/analytics/summary?period=${period}`),
      ]);
      setAccounts(accountsRes.data);
      setSummary(summaryRes.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  const periods: Period[] = ["day", "week", "month", "year"];

  return (
    <div className="flex flex-col gap-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Dashboard</h1>
          <p className="text-gray-500 text-sm mt-1">Your financial overview</p>
        </div>

        {/* Period selector */}
        <div
          className="flex gap-1 rounded-xl p-1"
          style={{ background: "rgba(255,255,255,0.05)" }}
        >
          {periods.map((p) => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={`px-4 py-1.5 rounded-lg text-sm font-medium capitalize transition-colors ${
                period === p ? "text-white" : "text-gray-400 hover:text-white"
              }`}
              style={period === p ? { background: "#6C63FF" } : {}}
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      {/* Hero Balance */}
      <Card className="text-center py-10">
        <p className="text-gray-400 text-sm mb-3">Total Balance</p>
        {loading ? (
          <Skeleton className="w-64 h-14 mx-auto mb-2" />
        ) : (
          <p className="text-5xl font-bold text-white mb-2">
            {formatCurrency(summary?.total_balance ?? 0)}
          </p>
        )}
        <p className="text-gray-600 text-xs">across all accounts</p>
      </Card>

      {/* Summary Stats */}
      <div className="grid grid-cols-3 gap-4">
        <Card>
          <div className="flex items-center gap-3 mb-3">
            <div
              className="p-2 rounded-lg"
              style={{ background: "rgba(74,222,128,0.1)" }}
            >
              <TrendingUp size={18} className="text-green-400" />
            </div>
            <p className="text-gray-400 text-sm">Income</p>
          </div>
          {loading ? (
            <Skeleton className="w-32 h-8" />
          ) : (
            <p className="text-2xl font-bold text-green-400">
              {formatCurrency(summary?.total_income ?? 0)}
            </p>
          )}
          <p className="text-gray-600 text-xs mt-1 capitalize">{period}</p>
        </Card>

        <Card>
          <div className="flex items-center gap-3 mb-3">
            <div
              className="p-2 rounded-lg"
              style={{ background: "rgba(248,113,113,0.1)" }}
            >
              <TrendingDown size={18} className="text-red-400" />
            </div>
            <p className="text-gray-400 text-sm">Expenses</p>
          </div>
          {loading ? (
            <Skeleton className="w-32 h-8" />
          ) : (
            <p className="text-2xl font-bold text-red-400">
              {formatCurrency(summary?.total_expenses ?? 0)}
            </p>
          )}
          <p className="text-gray-600 text-xs mt-1 capitalize">{period}</p>
        </Card>

        <Card>
          <div className="flex items-center gap-3 mb-3">
            <div
              className="p-2 rounded-lg"
              style={{ background: "rgba(167,139,250,0.1)" }}
            >
              <ArrowLeftRight size={18} className="text-purple-400" />
            </div>
            <p className="text-gray-400 text-sm">Net Change</p>
          </div>
          {loading ? (
            <Skeleton className="w-32 h-8" />
          ) : (
            <p
              className={`text-2xl font-bold ${(summary?.net_change ?? 0) >= 0 ? "text-green-400" : "text-red-400"}`}
            >
              {`${(summary?.net_change ?? 0) >= 0 ? "+" : "-"}${formatCurrency(summary?.net_change ?? 0)}`}
            </p>
          )}
          <p className="text-gray-600 text-xs mt-1 capitalize">{period}</p>
        </Card>
      </div>

      {/* Accounts */}
      <div>
        <h2 className="text-lg font-semibold text-white mb-4">Accounts</h2>

        {loading ? (
          <div className="grid grid-cols-3 gap-4">
            {[1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-36" />
            ))}
          </div>
        ) : accounts.length === 0 ? (
          <EmptyState
            icon="💳"
            message="No accounts yet"
            subMessage="Add an account to get started"
          />
        ) : (
          <div className="grid grid-cols-3 gap-4">
            {accounts.map((account) => (
              <Card key={account.id}>
                <div className="flex items-center gap-3 mb-4">
                  <div
                    className="w-3 h-3 rounded-full"
                    style={{ backgroundColor: account.color ?? "#6C63FF" }}
                  />
                  <p className="text-gray-400 text-sm capitalize">
                    {account.type}
                  </p>
                </div>
                <p className="text-white font-semibold mb-1">{account.name}</p>
                <p className="text-2xl font-bold text-white">
                  {formatCurrency(account.balance)}
                </p>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
