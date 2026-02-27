"use client";

import { useEffect, useState, useMemo } from "react";
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
  LayoutGrid,
  ShoppingBag,
  CalendarRange,
  Flame,
  Zap,
  Moon,
  Trophy,
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
  LineChart,
  Line,
  CartesianGrid,
} from "recharts";

type Period = "week" | "month" | "year" | "all" | "custom";
type Tab = "overview" | "categories" | "items" | "merchants";
type MoneyView = "merchant" | "category";

const COLORS = [
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
];

// ─── Tooltips ─────────────────────────────────────────────────────────────────
function ChartTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div
      className="rounded-xl px-4 py-3 text-sm"
      style={{
        background: "rgba(13,15,23,0.97)",
        border: "1px solid rgba(255,255,255,0.1)",
      }}
    >
      <p className="text-gray-400 mb-1 text-xs">{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} style={{ color: p.color }} className="font-semibold">
          {p.name}: {formatCurrency(p.value)}
        </p>
      ))}
    </div>
  );
}

function SimpleTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div
      className="rounded-xl px-3 py-2 text-sm"
      style={{
        background: "rgba(13,15,23,0.97)",
        border: "1px solid rgba(255,255,255,0.1)",
      }}
    >
      <p className="text-gray-400 text-xs">{label}</p>
      <p className="text-white font-semibold">
        {formatCurrency(payload[0].value)}
      </p>
    </div>
  );
}

function PieTooltip({ active, payload }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div
      className="rounded-xl px-3 py-2 text-sm"
      style={{
        background: "rgba(13,15,23,0.97)",
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

// ─── Period selector ──────────────────────────────────────────────────────────
function PeriodSelector({
  period,
  setPeriod,
  customFrom,
  customTo,
  setCustomFrom,
  setCustomTo,
  onApply,
}: {
  period: Period;
  setPeriod: (p: Period) => void;
  customFrom: string;
  customTo: string;
  setCustomFrom: (v: string) => void;
  setCustomTo: (v: string) => void;
  onApply: () => void;
}) {
  return (
    <div className="flex flex-col gap-3 items-end">
      <div
        className="flex gap-1 rounded-xl p-1"
        style={{ background: "rgba(255,255,255,0.05)" }}
      >
        {(["week", "month", "year", "all", "custom"] as Period[]).map((p) => (
          <button
            key={p}
            onClick={() => setPeriod(p)}
            className="px-3 py-1.5 rounded-lg text-sm font-medium capitalize transition-all whitespace-nowrap"
            style={
              period === p
                ? { background: "#6C63FF", color: "white" }
                : { color: "#9ca3af" }
            }
          >
            {p === "all" ? "All time" : p}
          </button>
        ))}
      </div>
      {period === "custom" && (
        <div
          className="flex items-center gap-3 px-4 py-3 rounded-xl"
          style={{
            background: "rgba(255,255,255,0.04)",
            border: "1px solid rgba(255,255,255,0.08)",
          }}
        >
          <CalendarRange size={15} className="text-gray-500 flex-shrink-0" />
          <input
            type="datetime-local"
            value={customFrom}
            onChange={(e) => setCustomFrom(e.target.value)}
            className="rounded-lg px-3 py-1.5 text-white text-sm outline-none"
            style={{
              background: "rgba(255,255,255,0.06)",
              colorScheme: "dark",
            }}
          />
          <span className="text-gray-600 text-sm">to</span>
          <input
            type="datetime-local"
            value={customTo}
            onChange={(e) => setCustomTo(e.target.value)}
            className="rounded-lg px-3 py-1.5 text-white text-sm outline-none"
            style={{
              background: "rgba(255,255,255,0.06)",
              colorScheme: "dark",
            }}
          />
          <button
            onClick={onApply}
            disabled={!customFrom || !customTo}
            className="px-4 py-1.5 rounded-lg text-sm font-medium disabled:opacity-40"
            style={{ background: "#6C63FF", color: "white" }}
          >
            Apply
          </button>
        </div>
      )}
    </div>
  );
}

// ─── Summary cards ────────────────────────────────────────────────────────────
function SummaryCards({
  summary,
  period,
  loading,
}: {
  summary: AnalyticsSummary | null;
  period: Period;
  loading: boolean;
}) {
  const days =
    period === "week"
      ? 7
      : period === "month"
        ? 30
        : period === "year"
          ? 365
          : null;
  const avgDaily = summary && days ? summary.total_expenses / days : null;

  if (loading)
    return (
      <div className="grid grid-cols-4 gap-4">
        {[1, 2, 3, 4].map((i) => (
          <Skeleton key={i} className="h-28" />
        ))}
      </div>
    );

  return (
    <div className="grid grid-cols-4 gap-4">
      <Card>
        <div className="flex items-center gap-2 mb-3">
          <TrendingUp size={15} className="text-green-400" />
          <p className="text-gray-500 text-xs">Income</p>
        </div>
        <p className="text-2xl font-bold text-green-400">
          {formatCurrency(summary?.total_income ?? 0)}
        </p>
      </Card>
      <Card>
        <div className="flex items-center gap-2 mb-3">
          <TrendingDown size={15} className="text-red-400" />
          <p className="text-gray-500 text-xs">Expenses</p>
        </div>
        <p className="text-2xl font-bold text-red-400">
          {formatCurrency(summary?.total_expenses ?? 0)}
        </p>
      </Card>
      <Card>
        <div className="flex items-center gap-2 mb-3">
          <ArrowLeftRight size={15} className="text-purple-400" />
          <p className="text-gray-500 text-xs">Net Change</p>
        </div>
        <p
          className={`text-2xl font-bold ${(summary?.net_change ?? 0) >= 0 ? "text-green-400" : "text-red-400"}`}
        >
          {(summary?.net_change ?? 0) >= 0 ? "+" : ""}
          {formatCurrency(summary?.net_change ?? 0)}
        </p>
      </Card>
      <Card>
        <div className="flex items-center gap-2 mb-3">
          <Calendar size={15} className="text-blue-400" />
          <p className="text-gray-500 text-xs">
            {avgDaily !== null ? "Avg Daily Spend" : "Transactions"}
          </p>
        </div>
        <p className="text-2xl font-bold text-blue-400">
          {avgDaily !== null
            ? formatCurrency(avgDaily)
            : (summary?.transaction_count ?? 0)}
        </p>
      </Card>
    </div>
  );
}

// ─── Notable stats ────────────────────────────────────────────────────────────
function NotableStats({
  transactions,
  loading,
}: {
  transactions: any[];
  loading: boolean;
}) {
  const stats = useMemo(() => {
    const expenses = transactions.filter((t) => t.type === "expense");
    if (!expenses.length) return null;

    // Biggest single transaction
    const biggest = expenses.reduce(
      (max, t) => (Number(t.amount) > Number(max.amount) ? t : max),
      expenses[0],
    );

    // Spending streak — consecutive days with expense ending today/yesterday
    const expenseDaySet = new Set(
      expenses.map((t) => new Date(t.date).toDateString()),
    );
    let streak = 0;
    const today = new Date();
    for (let i = 0; i < 365; i++) {
      const d = new Date(today);
      d.setDate(today.getDate() - i);
      if (expenseDaySet.has(d.toDateString())) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    // Biggest spending day
    const dayTotals: Record<string, number> = {};
    expenses.forEach((t) => {
      const key = new Date(t.date).toDateString();
      dayTotals[key] = (dayTotals[key] ?? 0) + Number(t.amount);
    });
    const biggestDayEntry = Object.entries(dayTotals).sort(
      (a, b) => b[1] - a[1],
    )[0];

    // No-spend days — within the date range of this dataset
    const dates = expenses.map((t) => new Date(t.date).getTime());
    const rangeStart = new Date(Math.min(...dates));
    const rangeEnd = new Date(Math.max(...dates));
    let noSpendCount = 0;
    for (
      let d = new Date(rangeStart);
      d <= rangeEnd;
      d.setDate(d.getDate() + 1)
    ) {
      if (!expenseDaySet.has(d.toDateString())) noSpendCount++;
    }

    return { biggest, streak, biggestDayEntry, noSpendCount };
  }, [transactions]);

  if (loading)
    return (
      <div className="grid grid-cols-4 gap-3">
        {[1, 2, 3, 4].map((i) => (
          <Skeleton key={i} className="h-16" />
        ))}
      </div>
    );
  if (!stats) return null;

  const items = [
    {
      icon: Trophy,
      color: "#FFD700",
      bg: "rgba(255,215,0,0.1)",
      label: "Biggest transaction",
      value: formatCurrency(stats.biggest.amount),
      sub: stats.biggest.merchant_name ?? stats.biggest.note ?? "Unknown",
    },
    {
      icon: Flame,
      color: "#FF6B6B",
      bg: "rgba(255,107,107,0.1)",
      label: "Spending streak",
      value: `${stats.streak} day${stats.streak !== 1 ? "s" : ""}`,
      sub:
        stats.streak > 4
          ? "Watch your wallet 👀"
          : stats.streak > 0
            ? "Active streak"
            : "No streak",
    },
    {
      icon: Zap,
      color: "#6C63FF",
      bg: "rgba(108,99,255,0.1)",
      label: "Biggest day",
      value: formatCurrency(stats.biggestDayEntry?.[1] ?? 0),
      sub: stats.biggestDayEntry
        ? new Date(stats.biggestDayEntry[0]).toLocaleDateString("en-IN", {
            day: "numeric",
            month: "short",
          })
        : "—",
    },
    {
      icon: Moon,
      color: "#4ECDC4",
      bg: "rgba(78,205,196,0.1)",
      label: "No-spend days",
      value: String(stats.noSpendCount),
      sub:
        stats.noSpendCount > 0 ? "Days with zero spending" : "Spent every day",
    },
  ];

  return (
    <div className="grid grid-cols-4 gap-3">
      {items.map(({ icon: Icon, color, bg, label, value, sub }) => (
        <div
          key={label}
          className="flex items-center gap-3 rounded-2xl px-4 py-3"
          style={{
            background: "rgba(255,255,255,0.03)",
            border: "1px solid rgba(255,255,255,0.06)",
          }}
        >
          <div
            className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ background: bg }}
          >
            <Icon size={16} style={{ color }} />
          </div>
          <div className="min-w-0">
            <p className="text-gray-500 text-xs">{label}</p>
            <p className="text-white text-sm font-bold truncate">{value}</p>
            <p className="text-gray-600 text-xs truncate">{sub}</p>
          </div>
        </div>
      ))}
    </div>
  );
}

// ─── Where did my money go ────────────────────────────────────────────────────
function WhereMoneyWent({
  categoryData,
  merchantData,
  loading,
}: {
  categoryData: any;
  merchantData: any;
  loading: boolean;
}) {
  const [view, setView] = useState<MoneyView>("merchant");

  const rows = useMemo(() => {
    if (view === "merchant") {
      return (merchantData?.merchants ?? [])
        .slice(0, 7)
        .map((m: any, i: number) => ({
          id: m.merchant_id ?? i,
          icon: "🏪",
          name: m.merchant_name ?? "Unknown",
          amount: m.total,
          count: m.transaction_count,
          color: COLORS[i % COLORS.length],
        }));
    }
    return (categoryData?.categories ?? [])
      .slice(0, 7)
      .map((c: any, i: number) => ({
        id: c.category_id ?? i,
        icon: c.category_icon ?? "📦",
        name: c.category_name ?? "Uncategorized",
        amount: c.total,
        count: c.transaction_count,
        color: c.category_color ?? COLORS[i % COLORS.length],
      }));
  }, [view, merchantData, categoryData]);

  const maxAmount = rows[0]?.amount ?? 1;
  const grandTotal = rows.reduce((s: number, r: any) => s + r.amount, 0);

  return (
    <Card>
      <div className="flex items-center justify-between mb-5">
        <div>
          <p className="text-white font-semibold">Where did my money go?</p>
          <p className="text-gray-600 text-xs mt-0.5">
            Total: {formatCurrency(grandTotal)}
          </p>
        </div>
        <div
          className="flex gap-1 rounded-xl p-1"
          style={{ background: "rgba(255,255,255,0.06)" }}
        >
          <button
            onClick={() => setView("merchant")}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
            style={
              view === "merchant"
                ? { background: "#6C63FF", color: "white" }
                : { color: "#6b7280" }
            }
          >
            <Store size={11} /> Merchants
          </button>
          <button
            onClick={() => setView("category")}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
            style={
              view === "category"
                ? { background: "#6C63FF", color: "white" }
                : { color: "#6b7280" }
            }
          >
            <LayoutGrid size={11} /> Categories
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col gap-3">
          {[1, 2, 3, 4, 5].map((i) => (
            <Skeleton key={i} className="h-8" />
          ))}
        </div>
      ) : rows.length === 0 ? (
        <div className="flex items-center justify-center py-8 text-gray-600 text-sm">
          No data for this period
        </div>
      ) : (
        <div className="flex flex-col gap-3.5">
          {rows.map((row: any) => {
            const pct = maxAmount > 0 ? (row.amount / maxAmount) * 100 : 0;
            const share =
              grandTotal > 0 ? Math.round((row.amount / grandTotal) * 100) : 0;
            return (
              <div key={row.id} className="flex items-center gap-3">
                <div
                  className="w-8 h-8 rounded-xl flex items-center justify-center text-sm flex-shrink-0"
                  style={{ background: `${row.color}18` }}
                >
                  {row.icon}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between mb-1.5">
                    <div className="flex items-center gap-2 min-w-0">
                      <span className="text-white text-sm font-medium truncate">
                        {row.name}
                      </span>
                      <span className="text-gray-600 text-xs flex-shrink-0">
                        {row.count}×
                      </span>
                    </div>
                    <div className="flex items-center gap-2 flex-shrink-0 ml-3">
                      <span className="text-gray-500 text-xs">{share}%</span>
                      <span className="text-white text-sm font-bold w-20 text-right">
                        {formatCurrency(row.amount)}
                      </span>
                    </div>
                  </div>
                  <div
                    className="h-1.5 rounded-full w-full"
                    style={{ background: "rgba(255,255,255,0.06)" }}
                  >
                    <div
                      className="h-1.5 rounded-full transition-all duration-500"
                      style={{ width: `${pct}%`, background: row.color }}
                    />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </Card>
  );
}

// ─── Overview tab ─────────────────────────────────────────────────────────────
function OverviewTab({
  loading,
  trendData,
  dayOfWeekData,
  transactions,
  categoryData,
  merchantData,
}: any) {
  const trendChartData =
    trendData?.data_points.map((d: any) => ({
      date: new Date(d.date).toLocaleDateString("en-IN", {
        day: "numeric",
        month: "short",
      }),
      Income: d.income,
      Expenses: d.expenses,
    })) ?? [];

  return (
    <div className="flex flex-col gap-5">
      {/* Notable stats strip */}
      <NotableStats transactions={transactions} loading={loading} />

      {/* Trend chart */}
      <Card>
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
                <linearGradient id="gIncome" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#22c55e" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#22c55e" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="gExpenses" x1="0" y1="0" x2="0" y2="1">
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
              <Tooltip content={<ChartTooltip />} />
              <Area
                type="monotone"
                dataKey="Income"
                stroke="#22c55e"
                strokeWidth={2}
                fill="url(#gIncome)"
              />
              <Area
                type="monotone"
                dataKey="Expenses"
                stroke="#ef4444"
                strokeWidth={2}
                fill="url(#gExpenses)"
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </Card>

      {/* Day of week + Where money went */}
      <div className="grid grid-cols-2 gap-4">
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
                <Tooltip content={<SimpleTooltip />} />
                <Bar dataKey="amount" radius={[6, 6, 0, 0]}>
                  {dayOfWeekData.map((_: any, i: number) => {
                    const maxIdx = dayOfWeekData.reduce(
                      (mI: number, d: any, idx: number, arr: any[]) =>
                        d.amount > arr[mI].amount ? idx : mI,
                      0,
                    );
                    return (
                      <Cell
                        key={i}
                        fill={
                          i === maxIdx ? "#6C63FF" : "rgba(108,99,255,0.25)"
                        }
                      />
                    );
                  })}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
          <p className="text-gray-600 text-xs mt-1 text-center">
            Purple = highest spending day
          </p>
        </Card>

        <WhereMoneyWent
          categoryData={categoryData}
          merchantData={merchantData}
          loading={loading}
        />
      </div>
    </div>
  );
}

// ─── Categories tab ───────────────────────────────────────────────────────────
function CategoriesTab({ loading, categoryData }: any) {
  if (loading)
    return (
      <div className="flex flex-col gap-4">
        {[1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-40" />
        ))}
      </div>
    );
  if (!categoryData?.categories?.length)
    return (
      <div className="flex items-center justify-center py-24 text-gray-600">
        No category data for this period
      </div>
    );

  return (
    <div className="grid grid-cols-5 gap-4">
      <Card className="col-span-2 flex flex-col">
        <p className="text-white font-semibold mb-4">Distribution</p>
        <div className="flex-1 flex items-center justify-center">
          <ResponsiveContainer width="100%" height={220}>
            <PieChart>
              <Pie
                data={categoryData.categories.slice(0, 8)}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={95}
                dataKey="total"
                nameKey="category_name"
                paddingAngle={3}
              >
                {categoryData.categories
                  .slice(0, 8)
                  .map((entry: any, i: number) => (
                    <Cell
                      key={entry.category_id}
                      fill={entry.category_color ?? COLORS[i % COLORS.length]}
                    />
                  ))}
              </Pie>
              <Tooltip content={<PieTooltip />} />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </Card>
      <Card className="col-span-3">
        <p className="text-white font-semibold mb-5">By Category</p>
        <div className="flex flex-col gap-4">
          {categoryData.categories.slice(0, 9).map((cat: any, i: number) => {
            const color = cat.category_color ?? COLORS[i % COLORS.length];
            const pct =
              categoryData.categories[0].total > 0
                ? (cat.total / categoryData.categories[0].total) * 100
                : 0;
            return (
              <div key={cat.category_id} className="flex flex-col gap-1.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="text-base w-5">
                      {cat.category_icon ?? "📦"}
                    </span>
                    <span className="text-white text-sm font-medium">
                      {cat.category_name ?? "Uncategorized"}
                    </span>
                    <span className="text-gray-600 text-xs">
                      {cat.transaction_count}x
                    </span>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-gray-500 text-xs">
                      {cat.percentage}%
                    </span>
                    <span className="text-white text-sm font-bold w-20 text-right">
                      {formatCurrency(cat.total)}
                    </span>
                  </div>
                </div>
                <div
                  className="h-1.5 rounded-full w-full"
                  style={{ background: "rgba(255,255,255,0.06)" }}
                >
                  <div
                    className="h-1.5 rounded-full transition-all"
                    style={{ width: `${pct}%`, background: color }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </Card>
    </div>
  );
}

// ─── Items tab ────────────────────────────────────────────────────────────────
function ItemsTab({ loading, itemsData }: any) {
  const [selectedItem, setSelectedItem] = useState<string | null>(null);

  if (loading)
    return (
      <div className="flex flex-col gap-4">
        {[1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-40" />
        ))}
      </div>
    );
  if (!itemsData?.top_items?.length)
    return (
      <div className="flex items-center justify-center py-24 text-gray-600">
        No item data yet — add transactions with items to see insights
      </div>
    );

  const priceHistory = selectedItem
    ? (itemsData.price_history?.[selectedItem] ?? [])
    : [];
  const selectedItemData = itemsData.top_items?.find(
    (i: any) => i.item_id === selectedItem,
  );

  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-2 gap-4">
        <Card>
          <p className="text-white font-semibold mb-1">Top Items by Spend</p>
          <p className="text-gray-600 text-xs mb-5">
            Click an item to see its price history →
          </p>
          <div className="flex flex-col gap-4">
            {itemsData.top_items.slice(0, 9).map((item: any, i: number) => {
              const isSelected = selectedItem === item.item_id;
              const pct =
                itemsData.top_items[0].total_spent > 0
                  ? (item.total_spent / itemsData.top_items[0].total_spent) *
                    100
                  : 0;
              return (
                <div
                  key={item.item_id}
                  className="flex flex-col gap-1.5 cursor-pointer group"
                  onClick={() =>
                    setSelectedItem(isSelected ? null : item.item_id)
                  }
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-gray-600 text-xs w-4 flex-shrink-0">
                        {i + 1}
                      </span>
                      <span
                        className={`text-sm font-medium transition-colors ${isSelected ? "text-purple-400" : "text-white group-hover:text-purple-300"}`}
                      >
                        {item.item_name}
                      </span>
                      <span
                        className="text-xs px-1.5 py-0.5 rounded-full flex-shrink-0"
                        style={{
                          background: "rgba(255,255,255,0.06)",
                          color: "#9ca3af",
                        }}
                      >
                        {item.purchase_count}×
                      </span>
                    </div>
                    <div className="text-right flex-shrink-0">
                      <p className="text-white text-sm font-bold">
                        {formatCurrency(item.total_spent)}
                      </p>
                      <p className="text-gray-600 text-xs">
                        avg {formatCurrency(item.avg_price)}
                      </p>
                    </div>
                  </div>
                  <div
                    className="h-1.5 rounded-full w-full"
                    style={{ background: "rgba(255,255,255,0.06)" }}
                  >
                    <div
                      className="h-1.5 rounded-full transition-all"
                      style={{
                        width: `${pct}%`,
                        background: isSelected
                          ? "#6C63FF"
                          : COLORS[i % COLORS.length],
                      }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </Card>

        <Card>
          {selectedItemData ? (
            <>
              <p className="text-white font-semibold mb-1">
                {selectedItemData.item_name}
              </p>
              <div className="flex items-center gap-5 mb-5">
                <div>
                  <p className="text-gray-600 text-xs">Avg price</p>
                  <p className="text-white text-sm font-bold">
                    {formatCurrency(selectedItemData.avg_price)}
                  </p>
                </div>
                <div>
                  <p className="text-gray-600 text-xs">Min</p>
                  <p className="text-green-400 text-sm font-bold">
                    {formatCurrency(selectedItemData.min_price)}
                  </p>
                </div>
                <div>
                  <p className="text-gray-600 text-xs">Max</p>
                  <p className="text-red-400 text-sm font-bold">
                    {formatCurrency(selectedItemData.max_price)}
                  </p>
                </div>
                <div>
                  <p className="text-gray-600 text-xs">Bought</p>
                  <p className="text-white text-sm font-bold">
                    {selectedItemData.purchase_count}×
                  </p>
                </div>
              </div>
            </>
          ) : (
            <>
              <p className="text-white font-semibold mb-1">Price History</p>
              <p className="text-gray-600 text-xs mb-5">
                Select an item on the left
              </p>
            </>
          )}
          {!selectedItem ? (
            <div className="h-52 flex flex-col items-center justify-center gap-3 text-gray-700">
              <ShoppingBag size={36} />
              <p className="text-sm">Select an item to view price trend</p>
            </div>
          ) : priceHistory.length < 2 ? (
            <div className="h-52 flex flex-col items-center justify-center gap-2 text-gray-700">
              <p className="text-sm">Not enough data yet</p>
              <p className="text-xs text-gray-600">
                Buy this item 2+ times to see a trend
              </p>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={220}>
              <LineChart data={priceHistory}>
                <CartesianGrid
                  strokeDasharray="3 3"
                  stroke="rgba(255,255,255,0.04)"
                />
                <XAxis
                  dataKey="date"
                  tick={{ fill: "#6b7280", fontSize: 10 }}
                  axisLine={false}
                  tickLine={false}
                  tickFormatter={(v) =>
                    new Date(v).toLocaleDateString("en-IN", {
                      day: "numeric",
                      month: "short",
                    })
                  }
                />
                <YAxis
                  tick={{ fill: "#6b7280", fontSize: 10 }}
                  axisLine={false}
                  tickLine={false}
                  width={55}
                  tickFormatter={(v) => `₹${v}`}
                />
                <Tooltip content={<SimpleTooltip />} />
                <Line
                  type="monotone"
                  dataKey="price"
                  stroke="#6C63FF"
                  strokeWidth={2.5}
                  dot={{ fill: "#6C63FF", r: 4, strokeWidth: 0 }}
                  activeDot={{ r: 6 }}
                />
              </LineChart>
            </ResponsiveContainer>
          )}
        </Card>
      </div>

      <Card>
        <p className="text-white font-semibold mb-1">Most Frequently Bought</p>
        <p className="text-gray-600 text-xs mb-5">
          Items you buy the most often
        </p>
        <div className="grid grid-cols-4 gap-3">
          {itemsData.top_items
            .slice()
            .sort((a: any, b: any) => b.purchase_count - a.purchase_count)
            .slice(0, 8)
            .map((item: any, i: number) => (
              <div
                key={item.item_id}
                className="rounded-2xl p-4 flex flex-col gap-2"
                style={{
                  background: "rgba(255,255,255,0.03)",
                  border: "1px solid rgba(255,255,255,0.06)",
                }}
              >
                <span
                  className="text-xs font-bold px-2 py-0.5 rounded-full self-start"
                  style={{
                    background: `${COLORS[i % COLORS.length]}22`,
                    color: COLORS[i % COLORS.length],
                  }}
                >
                  {item.purchase_count}×
                </span>
                <p className="text-white text-sm font-semibold">
                  {item.item_name}
                </p>
                <p className="text-gray-500 text-xs">
                  avg {formatCurrency(item.avg_price)}
                </p>
              </div>
            ))}
        </div>
      </Card>
    </div>
  );
}

// ─── Merchants tab ────────────────────────────────────────────────────────────
function MerchantsTab({ loading, merchantData }: any) {
  if (loading)
    return (
      <div className="flex flex-col gap-4">
        {[1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-40" />
        ))}
      </div>
    );
  if (!merchantData?.merchants?.length)
    return (
      <div className="flex items-center justify-center py-24 text-gray-600">
        No merchant data for this period
      </div>
    );

  return (
    <div className="grid grid-cols-2 gap-4">
      <Card>
        <p className="text-white font-semibold mb-6">Top Merchants by Spend</p>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart
            data={merchantData.merchants.slice(0, 8).map((m: any) => ({
              name:
                m.merchant_name?.length > 14
                  ? m.merchant_name.slice(0, 14) + "…"
                  : (m.merchant_name ?? "Unknown"),
              amount: m.total,
            }))}
            layout="vertical"
            barSize={18}
          >
            <XAxis
              type="number"
              tick={{ fill: "#6b7280", fontSize: 10 }}
              axisLine={false}
              tickLine={false}
              tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`}
            />
            <YAxis
              type="category"
              dataKey="name"
              tick={{ fill: "#9ca3af", fontSize: 11 }}
              axisLine={false}
              tickLine={false}
              width={100}
            />
            <Tooltip content={<SimpleTooltip />} />
            <Bar dataKey="amount" radius={[0, 6, 6, 0]}>
              {merchantData.merchants.slice(0, 8).map((_: any, i: number) => (
                <Cell key={i} fill={COLORS[i % COLORS.length]} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </Card>
      <Card>
        <p className="text-white font-semibold mb-5">Merchant Details</p>
        <div className="flex flex-col gap-4">
          {merchantData.merchants.slice(0, 8).map((m: any, i: number) => {
            const color = COLORS[i % COLORS.length];
            const pct =
              merchantData.merchants[0].total > 0
                ? (m.total / merchantData.merchants[0].total) * 100
                : 0;
            return (
              <div key={m.merchant_id ?? i} className="flex flex-col gap-1.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div
                      className="w-5 h-5 rounded-md flex items-center justify-center text-xs font-bold flex-shrink-0"
                      style={{ background: `${color}22`, color }}
                    >
                      {i + 1}
                    </div>
                    <span className="text-white text-sm font-medium">
                      {m.merchant_name ?? "Unknown"}
                    </span>
                    <span className="text-gray-600 text-xs">
                      {m.transaction_count}×
                    </span>
                  </div>
                  <span className="text-white text-sm font-bold">
                    {formatCurrency(m.total)}
                  </span>
                </div>
                <div
                  className="h-1.5 rounded-full w-full"
                  style={{ background: "rgba(255,255,255,0.05)" }}
                >
                  <div
                    className="h-1.5 rounded-full"
                    style={{ width: `${pct}%`, background: color }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </Card>
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────
export default function AnalyticsPage() {
  const [period, setPeriod] = useState<Period>("month");
  const [tab, setTab] = useState<Tab>("overview");
  const [customFrom, setCustomFrom] = useState("");
  const [customTo, setCustomTo] = useState("");
  const [activeParams, setActiveParams] = useState<{
    period: Period;
    from?: string;
    to?: string;
  }>({ period: "month" });

  const [summary, setSummary] = useState<AnalyticsSummary | null>(null);
  const [categoryData, setCategoryData] = useState<CategoryBreakdown | null>(
    null,
  );
  const [trendData, setTrendData] = useState<TrendData | null>(null);
  const [merchantData, setMerchantData] = useState<any>(null);
  const [itemsData, setItemsData] = useState<any>(null);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [dayOfWeekData, setDayOfWeekData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (period !== "custom") setActiveParams({ period });
  }, [period]);

  useEffect(() => {
    fetchAll(activeParams);
  }, [activeParams]);

  function handleApplyCustom() {
    if (!customFrom || !customTo) return;
    setActiveParams({ period: "custom", from: customFrom, to: customTo });
  }

  async function fetchAll({
    period,
    from,
    to,
  }: {
    period: Period;
    from?: string;
    to?: string;
  }) {
    setLoading(true);
    try {
      const params = new URLSearchParams({ period });
      if (period === "custom" && from && to) {
        params.set("from", new Date(from).toISOString());
        params.set("to", new Date(to).toISOString());
      }
      const qs = params.toString();

      // Derive the actual from/to for the transactions fetch so stats
      // are scoped to the selected period, not just the last N records
      const now = new Date();
      let txFrom: Date;
      if (period === "custom" && from) {
        txFrom = new Date(from);
      } else if (period === "week") {
        txFrom = new Date(now);
        txFrom.setDate(now.getDate() - 7);
      } else if (period === "month") {
        txFrom = new Date(now);
        txFrom.setDate(1);
        txFrom.setHours(0, 0, 0, 0);
      } else if (period === "year") {
        txFrom = new Date(now);
        txFrom.setMonth(0, 1);
        txFrom.setHours(0, 0, 0, 0);
      } else {
        txFrom = new Date(0); // all time
      }
      const txTo = period === "custom" && to ? new Date(to) : now;

      const txParams = new URLSearchParams({
        status: "completed",
        limit: "500",
      });
      txParams.set("from", txFrom.toISOString());
      txParams.set("to", txTo.toISOString());

      const [summaryRes, categoryRes, trendRes, merchantRes, txRes, itemsRes] =
        await Promise.all([
          api.get(`/api/analytics/summary?${qs}`),
          api.get(`/api/analytics/by-category?${qs}`),
          api.get(`/api/analytics/trends?${qs}`),
          api.get(`/api/analytics/by-merchant?${qs}`),
          api.get(`/api/transactions?${txParams.toString()}`),
          api.get(`/api/analytics/by-item?${qs}`).catch(() => ({ data: null })),
        ]);

      setSummary(summaryRes.data);
      setCategoryData(categoryRes.data);
      setTrendData(trendRes.data);
      setMerchantData(merchantRes.data);
      setItemsData(itemsRes.data);
      setTransactions(txRes.data);

      const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
      const dayTotals: Record<string, number> = {};
      days.forEach((d) => (dayTotals[d] = 0));
      txRes.data
        .filter((t: any) => t.type === "expense")
        .forEach((t: any) => {
          dayTotals[days[new Date(t.date).getDay()]] += Number(t.amount);
        });
      setDayOfWeekData(days.map((d) => ({ day: d, amount: dayTotals[d] })));
    } catch {
      showToast("error", "Could not load analytics");
    } finally {
      setLoading(false);
    }
  }

  const tabs: { id: Tab; label: string; icon: any }[] = [
    { id: "overview", label: "Overview", icon: LayoutGrid },
    { id: "categories", label: "Categories", icon: ArrowLeftRight },
    { id: "items", label: "Items", icon: ShoppingBag },
    { id: "merchants", label: "Merchants", icon: Store },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-start justify-between gap-6">
        <div>
          <h1 className="text-2xl font-bold text-white">Analytics</h1>
          <p className="text-gray-500 text-sm mt-1">Your spending insights</p>
        </div>
        <PeriodSelector
          period={period}
          setPeriod={setPeriod}
          customFrom={customFrom}
          customTo={customTo}
          setCustomFrom={setCustomFrom}
          setCustomTo={setCustomTo}
          onApply={handleApplyCustom}
        />
      </div>

      <SummaryCards
        summary={summary}
        period={activeParams.period}
        loading={loading}
      />

      <div
        className="flex gap-1 rounded-2xl p-1"
        style={{
          background: "rgba(255,255,255,0.04)",
          border: "1px solid rgba(255,255,255,0.06)",
        }}
      >
        {tabs.map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => setTab(id)}
            className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium transition-all"
            style={
              tab === id
                ? {
                    background: "rgba(108,99,255,0.15)",
                    color: "#a78bfa",
                    border: "1px solid rgba(108,99,255,0.2)",
                  }
                : { color: "#6b7280" }
            }
          >
            <Icon size={14} />
            {label}
          </button>
        ))}
      </div>

      {tab === "overview" && (
        <OverviewTab
          loading={loading}
          trendData={trendData}
          dayOfWeekData={dayOfWeekData}
          transactions={transactions}
          categoryData={categoryData}
          merchantData={merchantData}
        />
      )}
      {tab === "categories" && (
        <CategoriesTab loading={loading} categoryData={categoryData} />
      )}
      {tab === "items" && <ItemsTab loading={loading} itemsData={itemsData} />}
      {tab === "merchants" && (
        <MerchantsTab loading={loading} merchantData={merchantData} />
      )}
    </div>
  );
}
