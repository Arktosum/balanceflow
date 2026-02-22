"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { AnalyticsSummary, CategoryBreakdown, TrendData } from "@/lib/types";
import Card from "@/components/ui/Card";
import { Skeleton } from "@/components/ui/Skeleton";
import { showToast } from "@/components/ui/Toast";
import { formatCurrency } from "@/lib/utils";
import {
  TrendingUp,
  TrendingDown,
  ArrowLeftRight,
  Store,
  Calendar,
} from "lucide-react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
} from "recharts";

type Period = "day" | "week" | "month" | "year";

const CHART_COLORS = [
  "#6C63FF",
  "#FF6B6B",
  "#4ECDC4",
  "#45B7D1",
  "#96CEB4",
  "#FFEAA7",
  "#DDA0DD",
  "#F1948A",
  "#85C1E9",
  "#82E0AA",
  "#A0522D",
  "#F7DC6F",
];

function CustomTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div
      className="rounded-xl px-4 py-3 text-sm"
      style={{
        background: "rgba(20,22,35,0.95)",
        border: "1px solid rgba(255,255,255,0.1)",
      }}
    >
      <p className="text-gray-400 mb-2">{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} style={{ color: p.color }} className="font-medium">
          {p.name}: {formatCurrency(p.value)}
        </p>
      ))}
    </div>
  );
}

function PieTooltip({ active, payload }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div
      className="rounded-xl px-4 py-3 text-sm"
      style={{
        background: "rgba(20,22,35,0.95)",
        border: "1px solid rgba(255,255,255,0.1)",
      }}
    >
      <p className="text-white font-medium">{payload[0].name}</p>
      <p style={{ color: payload[0].payload.fill }}>
        {formatCurrency(payload[0].value)}
      </p>
      <p className="text-gray-400">{payload[0].payload.percentage}%</p>
    </div>
  );
}

export default function AnalyticsPage() {
  const [period, setPeriod] = useState<Period>("month");
  const [summary, setSummary] = useState<AnalyticsSummary | null>(null);
  const [categoryData, setCategoryData] = useState<CategoryBreakdown | null>(
    null,
  );
  const [trendData, setTrendData] = useState<TrendData | null>(null);
  const [merchantData, setMerchantData] = useState<any>(null);
  const [topTransactions, setTopTransactions] = useState<any[]>([]);
  const [dayOfWeekData, setDayOfWeekData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchAll();
  }, [period]);

  async function fetchAll() {
    setLoading(true);
    try {
      const [summaryRes, categoryRes, trendRes, merchantRes, txRes] =
        await Promise.all([
          api.get(`/api/analytics/summary?period=${period}`),
          api.get(`/api/analytics/by-category?period=${period}`),
          api.get(`/api/analytics/trends?period=${period}`),
          api.get(`/api/analytics/by-merchant?period=${period}`),
          api.get(`/api/transactions?status=completed&limit=100`),
        ]);

      setSummary(summaryRes.data);
      setCategoryData(categoryRes.data);
      setTrendData(trendRes.data);
      setMerchantData(merchantRes.data);

      // top 5 biggest expense transactions
      const expenses = txRes.data
        .filter((t: any) => t.type === "expense")
        .sort((a: any, b: any) => b.amount - a.amount)
        .slice(0, 5);
      setTopTransactions(expenses);

      // day of week breakdown
      const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
      const dayTotals: Record<string, number> = {};
      days.forEach((d) => (dayTotals[d] = 0));
      txRes.data
        .filter((t: any) => t.type === "expense")
        .forEach((t: any) => {
          const day = days[new Date(t.date).getDay()];
          dayTotals[day] += Number(t.amount);
        });
      setDayOfWeekData(days.map((d) => ({ day: d, amount: dayTotals[d] })));
    } catch {
      showToast("error", "Could not load analytics");
    } finally {
      setLoading(false);
    }
  }

  const periods: Period[] = ["day", "week", "month", "year"];

  const avgDailySpend = summary
    ? period === "day"
      ? summary.total_expenses
      : period === "week"
        ? summary.total_expenses / 7
        : period === "month"
          ? summary.total_expenses / 30
          : summary.total_expenses / 365
    : 0;

  const trendChartData =
    trendData?.data_points.map((d) => ({
      date: new Date(d.date).toLocaleDateString("en-IN", {
        day: "numeric",
        month: "short",
      }),
      Income: d.income,
      Expenses: d.expenses,
    })) ?? [];

  return (
    <div className="flex flex-col gap-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Analytics</h1>
          <p className="text-gray-500 text-sm mt-1">Your spending insights</p>
        </div>
        <div
          className="flex gap-1 rounded-xl p-1"
          style={{ background: "rgba(255,255,255,0.05)" }}
        >
          {periods.map((p) => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className="px-4 py-1.5 rounded-lg text-sm font-medium capitalize transition-colors"
              style={
                period === p
                  ? { background: "#6C63FF", color: "white" }
                  : { color: "#9ca3af" }
              }
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      {/* Summary row */}
      {loading ? (
        <div className="grid grid-cols-4 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <Skeleton key={i} className="h-28" />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-4 gap-4">
          <Card>
            <div className="flex items-center gap-2 mb-3">
              <TrendingUp size={16} className="text-green-400" />
              <p className="text-gray-400 text-xs">Income</p>
            </div>
            <p className="text-xl font-bold text-green-400">
              {formatCurrency(summary?.total_income ?? 0)}
            </p>
          </Card>
          <Card>
            <div className="flex items-center gap-2 mb-3">
              <TrendingDown size={16} className="text-red-400" />
              <p className="text-gray-400 text-xs">Expenses</p>
            </div>
            <p className="text-xl font-bold text-red-400">
              {formatCurrency(summary?.total_expenses ?? 0)}
            </p>
          </Card>
          <Card>
            <div className="flex items-center gap-2 mb-3">
              <ArrowLeftRight size={16} className="text-purple-400" />
              <p className="text-gray-400 text-xs">Net Change</p>
            </div>
            <p
              className={`text-xl font-bold ${(summary?.net_change ?? 0) >= 0 ? "text-green-400" : "text-red-400"}`}
            >
              {(summary?.net_change ?? 0) >= 0 ? "+" : ""}
              {formatCurrency(summary?.net_change ?? 0)}
            </p>
          </Card>
          <Card>
            <div className="flex items-center gap-2 mb-3">
              <Calendar size={16} className="text-blue-400" />
              <p className="text-gray-400 text-xs">Avg Daily Spend</p>
            </div>
            <p className="text-xl font-bold text-blue-400">
              {formatCurrency(avgDailySpend)}
            </p>
          </Card>
        </div>
      )}

      {/* Trend chart + Category donut */}
      <div className="grid grid-cols-5 gap-4">
        {/* Trend chart — 3 cols */}
        <Card className="col-span-3">
          <p className="text-white font-semibold mb-6">Income vs Expenses</p>
          {loading ? (
            <Skeleton className="h-56" />
          ) : trendChartData.length === 0 ? (
            <div className="h-56 flex items-center justify-center text-gray-600 text-sm">
              No data for this period
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={220}>
              <AreaChart data={trendChartData}>
                <defs>
                  <linearGradient id="colorIncome" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#22c55e" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#22c55e" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient
                    id="colorExpenses"
                    x1="0"
                    y1="0"
                    x2="0"
                    y2="1"
                  >
                    <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis
                  dataKey="date"
                  tick={{ fill: "#6b7280", fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fill: "#6b7280", fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                  width={60}
                  tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`}
                />
                <Tooltip content={<CustomTooltip />} />
                <Area
                  type="monotone"
                  dataKey="Income"
                  stroke="#22c55e"
                  strokeWidth={2}
                  fill="url(#colorIncome)"
                />
                <Area
                  type="monotone"
                  dataKey="Expenses"
                  stroke="#ef4444"
                  strokeWidth={2}
                  fill="url(#colorExpenses)"
                />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </Card>

        {/* Category donut — 2 cols */}
        <Card className="col-span-2">
          <p className="text-white font-semibold mb-4">Spending by Category</p>
          {loading ? (
            <Skeleton className="h-56" />
          ) : !categoryData || categoryData.categories.length === 0 ? (
            <div className="h-56 flex items-center justify-center text-gray-600 text-sm">
              No expenses yet
            </div>
          ) : (
            <div className="flex flex-col items-center">
              <ResponsiveContainer width="100%" height={160}>
                <PieChart>
                  <Pie
                    data={categoryData.categories.slice(0, 6)}
                    cx="50%"
                    cy="50%"
                    innerRadius={45}
                    outerRadius={75}
                    dataKey="total"
                    nameKey="category_name"
                    paddingAngle={3}
                  >
                    {categoryData.categories.slice(0, 6).map((entry, index) => (
                      <Cell
                        key={entry.category_id}
                        fill={
                          entry.category_color ??
                          CHART_COLORS[index % CHART_COLORS.length]
                        }
                      />
                    ))}
                  </Pie>
                  <Tooltip content={<PieTooltip />} />
                </PieChart>
              </ResponsiveContainer>

              {/* Legend */}
              <div className="w-full flex flex-col gap-1.5 mt-2">
                {categoryData.categories.slice(0, 5).map((cat, i) => (
                  <div
                    key={cat.category_id}
                    className="flex items-center justify-between"
                  >
                    <div className="flex items-center gap-2">
                      <div
                        className="w-2 h-2 rounded-full flex-shrink-0"
                        style={{
                          background:
                            cat.category_color ??
                            CHART_COLORS[i % CHART_COLORS.length],
                        }}
                      />
                      <span className="text-gray-400 text-xs truncate max-w-[100px]">
                        {cat.category_icon}{" "}
                        {cat.category_name ?? "Uncategorized"}
                      </span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-gray-600 text-xs">
                        {cat.percentage}%
                      </span>
                      <span className="text-white text-xs font-medium">
                        {formatCurrency(cat.total)}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </Card>
      </div>

      {/* Day of week + Top merchants */}
      <div className="grid grid-cols-2 gap-4">
        {/* Day of week */}
        <Card>
          <p className="text-white font-semibold mb-6">
            Spending by Day of Week
          </p>
          {loading ? (
            <Skeleton className="h-48" />
          ) : (
            <ResponsiveContainer width="100%" height={180}>
              <BarChart data={dayOfWeekData} barSize={28}>
                <XAxis
                  dataKey="day"
                  tick={{ fill: "#6b7280", fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis hide />
                <Tooltip
                  content={({ active, payload, label }) =>
                    active && payload?.length ? (
                      <div
                        className="rounded-xl px-3 py-2 text-sm"
                        style={{
                          background: "rgba(20,22,35,0.95)",
                          border: "1px solid rgba(255,255,255,0.1)",
                        }}
                      >
                        <p className="text-gray-400">{label}</p>
                        <p className="text-white font-medium">
                          {formatCurrency(payload[0].value as number)}
                        </p>
                      </div>
                    ) : null
                  }
                />
                <Bar dataKey="amount" radius={[6, 6, 0, 0]}>
                  {dayOfWeekData.map((_: any, index: number) => (
                    <Cell
                      key={index}
                      fill={
                        index ===
                        dayOfWeekData.reduce(
                          (maxI, d, i, arr) =>
                            d.amount > arr[maxI].amount ? i : maxI,
                          0,
                        )
                          ? "#6C63FF"
                          : "rgba(108,99,255,0.3)"
                      }
                    />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
          <p className="text-gray-600 text-xs mt-2 text-center">
            Highlighted bar = highest spending day
          </p>
        </Card>

        {/* Top merchants */}
        <Card>
          <div className="flex items-center gap-2 mb-4">
            <Store size={16} className="text-purple-400" />
            <p className="text-white font-semibold">Top Merchants</p>
          </div>
          {loading ? (
            <div className="flex flex-col gap-3">
              {[1, 2, 3, 4, 5].map((i) => (
                <Skeleton key={i} className="h-10" />
              ))}
            </div>
          ) : !merchantData || merchantData.merchants.length === 0 ? (
            <div className="flex items-center justify-center h-48 text-gray-600 text-sm">
              No merchant data yet
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              {merchantData.merchants.slice(0, 6).map((m: any, i: number) => {
                const maxAmount = merchantData.merchants[0].total;
                const pct = maxAmount > 0 ? (m.total / maxAmount) * 100 : 0;
                return (
                  <div key={m.merchant_id ?? i} className="flex flex-col gap-1">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-gray-600 text-xs w-4">
                          {i + 1}
                        </span>
                        <span className="text-white text-sm font-medium">
                          {m.merchant_name ?? "Unknown"}
                        </span>
                        <span className="text-gray-600 text-xs">
                          {m.transaction_count}x
                        </span>
                      </div>
                      <span className="text-white text-sm font-bold">
                        {formatCurrency(m.total)}
                      </span>
                    </div>
                    <div
                      className="h-1 rounded-full w-full"
                      style={{ background: "rgba(255,255,255,0.06)" }}
                    >
                      <div
                        className="h-1 rounded-full transition-all"
                        style={{
                          width: `${pct}%`,
                          background: CHART_COLORS[i % CHART_COLORS.length],
                        }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </Card>
      </div>

      {/* Biggest transactions */}
      <Card>
        <p className="text-white font-semibold mb-4">Biggest Expenses</p>
        {loading ? (
          <div className="flex flex-col gap-3">
            {[1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : topTransactions.length === 0 ? (
          <div className="flex items-center justify-center py-8 text-gray-600 text-sm">
            No expenses yet
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            {topTransactions.map((tx, i) => (
              <div
                key={tx.id}
                className="flex items-center gap-4 py-3 border-b"
                style={{ borderColor: "rgba(255,255,255,0.05)" }}
              >
                <span
                  className="text-lg font-bold w-6 text-center"
                  style={{
                    color:
                      i === 0
                        ? "#FFD700"
                        : i === 1
                          ? "#C0C0C0"
                          : i === 2
                            ? "#CD7F32"
                            : "#6b7280",
                  }}
                >
                  {i + 1}
                </span>
                <div
                  className="w-9 h-9 rounded-full flex items-center justify-center text-base flex-shrink-0"
                  style={{
                    background: tx.category_color
                      ? `${tx.category_color}22`
                      : "rgba(108,99,255,0.15)",
                  }}
                >
                  {tx.category_icon ?? "💸"}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-white text-sm font-medium truncate">
                    {tx.merchant_name ?? tx.note ?? "Unknown"}
                  </p>
                  <p className="text-gray-500 text-xs">
                    {tx.category_name ?? "Uncategorized"} •{" "}
                    {new Date(tx.date).toLocaleDateString("en-IN", {
                      day: "numeric",
                      month: "short",
                    })}
                  </p>
                </div>
                <p className="text-red-400 font-bold text-sm">
                  {formatCurrency(tx.amount)}
                </p>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
