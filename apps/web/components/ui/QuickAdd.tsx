"use client";

import { useState, useEffect } from "react";
import { Plus, X } from "lucide-react";
import api from "@/lib/api";
import { Account, Category, Merchant } from "@/lib/types";
import { showToast } from "@/components/ui/Toast";

type TransactionType = "expense" | "income" | "transfer";

function nowDateTimeLocal() {
  const now = new Date();
  now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
  return now.toISOString().slice(0, 16);
}

export default function QuickAdd() {
  const [open, setOpen] = useState(false);
  const [type, setType] = useState<TransactionType>("expense");
  const [amount, setAmount] = useState("");
  const [accountId, setAccountId] = useState("");
  const [toAccountId, setToAccountId] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [merchantName, setMerchantName] = useState("");
  const [note, setNote] = useState("");
  const [status, setStatus] = useState<"completed" | "pending">("completed");
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [filteredMerchants, setFilteredMerchants] = useState<Merchant[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [customDate, setCustomDate] = useState(false);
  const [dateValue, setDateValue] = useState("");

  const [debtPerson, setDebtPerson] = useState("");
  const [debtDirection, setDebtDirection] = useState<"i_owe" | "they_owe">(
    "i_owe",
  );

  useEffect(() => {
    if (open) fetchData();
  }, [open]);

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
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") close();
    }
    if (open) window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [open]);

  async function fetchData() {
    const [accountsRes, categoriesRes, merchantsRes] = await Promise.all([
      api.get("/api/accounts"),
      api.get("/api/categories"),
      api.get("/api/merchants"),
    ]);
    setAccounts(accountsRes.data);
    setCategories(categoriesRes.data);
    setMerchants(merchantsRes.data);
    if (accountsRes.data.length > 0) setAccountId(accountsRes.data[0].id);
  }

  function reset() {
    setAmount("");
    setAccountId(accounts[0]?.id ?? "");
    setToAccountId("");
    setCategoryId("");
    setMerchantName("");
    setNote("");
    setStatus("completed");
    setType("expense");
    setError("");
    setCustomDate(false);
    setDateValue("");
    setDebtPerson("");
    setDebtDirection("i_owe");
  }

  function close() {
    setOpen(false);
    reset();
  }

  async function handleSubmit() {
    if (!amount || isNaN(parseFloat(amount)) || parseFloat(amount) <= 0) {
      setError("Enter a valid amount");
      return;
    }
    if (!accountId) {
      setError("Select an account");
      return;
    }
    if (type === "transfer" && !toAccountId) {
      setError("Select a destination account");
      return;
    }

    setSubmitting(true);
    setError("");

    try {
      // find or create merchant
      let merchantId: string | undefined;
      if (merchantName.trim() && type !== "transfer") {
        const existing = merchants.find(
          (m) => m.name.toLowerCase() === merchantName.toLowerCase(),
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

      const payload: any = {
        type,
        amount: parseFloat(amount),
        account_id: accountId,
        note: note || undefined,
        status,
        date:
          customDate && dateValue
            ? new Date(dateValue).toISOString()
            : undefined,
      };

      if (type === "transfer") {
        payload.to_account_id = toAccountId;
      } else {
        if (categoryId) payload.category_id = categoryId;
        if (merchantId) payload.merchant_id = merchantId;
      }

      const txRes = await api.post("/api/transactions", payload);

      if (txRes.data.status === "pending" && debtPerson.trim()) {
        await api.post("/api/debts", {
          transaction_id: txRes.data.id,
          person_name: debtPerson.trim(),
          direction: debtDirection,
        });
      }

      showToast("success", "Transaction added successfully!");
      close();
      window.dispatchEvent(new Event("transaction-added"));

    } catch (err: any) {
      const message = err.response?.data?.error ?? "Something went wrong";
      setError(message);
      showToast("error", message);
    } finally {
      setSubmitting(false);
    }
  }

  const filteredCategories = categories.filter(
    (c) => c.type === type || c.type === "both",
  );

  return (
    <>
      {/* Floating Button */}
      <button
        onClick={() => setOpen(true)}
        className="fixed bottom-8 right-8 w-14 h-14 rounded-full flex items-center justify-center shadow-lg transition-transform hover:scale-110 z-50"
        style={{ background: "linear-gradient(135deg, #6C63FF, #00D2FF)" }}
      >
        <Plus size={24} className="text-white" />
      </button>

      {/* Backdrop */}
      {open && (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center"
          style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)" }}
          onClick={(e) => {
            if (e.target === e.currentTarget) close();
          }}
        >
          {/* Modal */}
          <div
            className="w-full max-w-lg rounded-t-3xl p-6 flex flex-col gap-5"
            style={{
              background: "rgba(20, 22, 35, 0.98)",
              border: "1px solid rgba(255,255,255,0.1)",
              backdropFilter: "blur(20px)",
            }}
          >
            {/* Header */}
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-white">Add Transaction</h2>
              <button
                onClick={close}
                className="text-gray-400 hover:text-white transition-colors"
              >
                <X size={20} />
              </button>
            </div>

            {/* Type selector */}
            <div
              className="flex rounded-xl p-1 gap-1"
              style={{ background: "rgba(255,255,255,0.05)" }}
            >
              {(["expense", "income", "transfer"] as TransactionType[]).map(
                (t) => (
                  <button
                    key={t}
                    onClick={() => {
                      setType(t);
                      setCategoryId("");
                    }}
                    className="flex-1 py-2 rounded-lg text-sm font-medium capitalize transition-colors"
                    style={
                      type === t
                        ? {
                            background:
                              t === "expense"
                                ? "#ef4444"
                                : t === "income"
                                  ? "#22c55e"
                                  : "#6C63FF",
                            color: "white",
                          }
                        : { color: "#9ca3af" }
                    }
                  >
                    {t}
                  </button>
                ),
              )}
            </div>

            {/* Amount */}
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Amount</label>
              <div
                className="flex items-center gap-2 rounded-xl px-4 py-3"
                style={{ background: "rgba(255,255,255,0.06)" }}
              >
                <span className="text-gray-400 text-lg">₹</span>
                <input
                  type="number"
                  placeholder="0.00"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  className="flex-1 bg-transparent text-white text-2xl font-bold outline-none placeholder-gray-700"
                  autoFocus
                />
              </div>
            </div>

            {/* Account */}
            <div>
              <label className="text-xs text-gray-500 mb-1 block">
                From Account
              </label>
              <select
                value={accountId}
                onChange={(e) => setAccountId(e.target.value)}
                className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none"
                style={{ background: "rgba(255,255,255,0.06)" }}
              >
                {accounts.map((a) => (
                  <option
                    key={a.id}
                    value={a.id}
                    style={{ background: "#1a1d2e" }}
                  >
                    {a.name} — ₹{Number(a.balance).toLocaleString("en-IN")}
                  </option>
                ))}
              </select>
            </div>

            {/* To Account (transfer only) */}
            {type === "transfer" && (
              <div>
                <label className="text-xs text-gray-500 mb-1 block">
                  To Account
                </label>
                <select
                  value={toAccountId}
                  onChange={(e) => setToAccountId(e.target.value)}
                  className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none"
                  style={{ background: "rgba(255,255,255,0.06)" }}
                >
                  <option value="" style={{ background: "#1a1d2e" }}>
                    Select account
                  </option>
                  {accounts
                    .filter((a) => a.id !== accountId)
                    .map((a) => (
                      <option
                        key={a.id}
                        value={a.id}
                        style={{ background: "#1a1d2e" }}
                      >
                        {a.name}
                      </option>
                    ))}
                </select>
              </div>
            )}

            {/* Category + Merchant (non-transfer) */}
            {type !== "transfer" && (
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs text-gray-500 mb-1 block">
                    Category
                  </label>
                  <select
                    value={categoryId}
                    onChange={(e) => setCategoryId(e.target.value)}
                    className="w-full rounded-xl px-3 py-3 text-white text-sm outline-none"
                    style={{ background: "rgba(255,255,255,0.06)" }}
                  >
                    <option value="" style={{ background: "#1a1d2e" }}>
                      None
                    </option>
                    {filteredCategories.map((c) => (
                      <option
                        key={c.id}
                        value={c.id}
                        style={{ background: "#1a1d2e" }}
                      >
                        {c.icon} {c.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="relative">
                  <label className="text-xs text-gray-500 mb-1 block">
                    Merchant / Person
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. Swiggy"
                    value={merchantName}
                    onChange={(e) => setMerchantName(e.target.value)}
                    className="w-full rounded-xl px-3 py-3 text-white text-sm outline-none placeholder-gray-700"
                    style={{ background: "rgba(255,255,255,0.06)" }}
                  />
                  {/* Autocomplete dropdown */}
                  {filteredMerchants.length > 0 && (
                    <div
                      className="absolute top-full left-0 right-0 rounded-xl mt-1 overflow-hidden z-10"
                      style={{
                        background: "#1a1d2e",
                        border: "1px solid rgba(255,255,255,0.1)",
                      }}
                    >
                      {filteredMerchants.map((m) => (
                        <button
                          key={m.id}
                          onClick={() => {
                            setMerchantName(m.name);
                            setFilteredMerchants([]);
                          }}
                          className="w-full text-left px-3 py-2 text-sm text-gray-300 hover:text-white hover:bg-white/5 transition-colors"
                        >
                          {m.name}
                          {m.transaction_count >= 3 && (
                            <span className="ml-2 text-xs text-purple-400">
                              regular
                            </span>
                          )}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}
            {/* Date */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="text-xs text-gray-500">Date & Time</label>
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-500">Custom</span>
                  <button
                    onClick={() => {
                      setCustomDate(!customDate);
                      if (!customDate) setDateValue(nowDateTimeLocal());
                    }}
                    className="w-10 h-5 rounded-full transition-colors relative"
                    style={{
                      background: customDate
                        ? "#6C63FF"
                        : "rgba(255,255,255,0.1)",
                    }}
                  >
                    <div
                      className="absolute top-0.5 w-4 h-4 rounded-full bg-white transition-all"
                      style={{ left: customDate ? "1.25rem" : "0.125rem" }}
                    />
                  </button>
                </div>
              </div>

              {customDate ? (
                <input
                  type="datetime-local"
                  value={dateValue}
                  onChange={(e) => setDateValue(e.target.value)}
                  className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none"
                  style={{
                    background: "rgba(255,255,255,0.06)",
                    colorScheme: "dark",
                  }}
                />
              ) : (
                <p
                  className="text-gray-500 text-sm px-4 py-3 rounded-xl"
                  style={{ background: "rgba(255,255,255,0.03)" }}
                >
                  Now —{" "}
                  {new Date().toLocaleString("en-IN", {
                    dateStyle: "medium",
                    timeStyle: "short",
                  })}
                </p>
              )}
            </div>

            {/* Note */}
            <div>
              <label className="text-xs text-gray-500 mb-1 block">
                Note (optional)
              </label>
              <input
                type="text"
                placeholder="What was this for?"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none placeholder-gray-700"
                style={{ background: "rgba(255,255,255,0.06)" }}
              />
            </div>

            {/* Pending toggle */}
            {type !== "transfer" && (
              <div className="flex flex-col gap-3">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-white">Mark as pending</p>
                    <p className="text-xs text-gray-500">
                      Won't affect balance until settled
                    </p>
                  </div>
                  <button
                    onClick={() =>
                      setStatus(
                        status === "completed" ? "pending" : "completed",
                      )
                    }
                    className="w-12 h-6 rounded-full transition-colors relative"
                    style={{
                      background:
                        status === "pending"
                          ? "#6C63FF"
                          : "rgba(255,255,255,0.1)",
                    }}
                  >
                    <div
                      className="absolute top-1 w-4 h-4 rounded-full bg-white transition-all"
                      style={{
                        left: status === "pending" ? "1.5rem" : "0.25rem",
                      }}
                    />
                  </button>
                </div>

                {/* Debt fields — only show when pending */}
                {status === "pending" && (
                  <div
                    className="flex flex-col gap-3 rounded-xl p-4"
                    style={{
                      background: "rgba(255,255,255,0.03)",
                      border: "1px solid rgba(255,255,255,0.06)",
                    }}
                  >
                    <p className="text-xs text-gray-500 font-medium uppercase tracking-wider">
                      Debt Details
                    </p>

                    <div>
                      <label className="text-xs text-gray-500 mb-1 block">
                        Person Name
                      </label>
                      <input
                        type="text"
                        placeholder="e.g. Rahul"
                        value={debtPerson}
                        onChange={(e) => setDebtPerson(e.target.value)}
                        className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none placeholder-gray-700"
                        style={{ background: "rgba(255,255,255,0.06)" }}
                      />
                    </div>

                    <div>
                      <label className="text-xs text-gray-500 mb-1 block">
                        Direction
                      </label>
                      <div className="flex gap-2">
                        <button
                          onClick={() => setDebtDirection("i_owe")}
                          className="flex-1 py-2 rounded-xl text-sm font-medium transition-colors"
                          style={
                            debtDirection === "i_owe"
                              ? {
                                  background: "rgba(239,68,68,0.2)",
                                  color: "#ef4444",
                                }
                              : {
                                  background: "rgba(255,255,255,0.05)",
                                  color: "#9ca3af",
                                }
                          }
                        >
                          I owe them
                        </button>
                        <button
                          onClick={() => setDebtDirection("they_owe")}
                          className="flex-1 py-2 rounded-xl text-sm font-medium transition-colors"
                          style={
                            debtDirection === "they_owe"
                              ? {
                                  background: "rgba(34,197,94,0.2)",
                                  color: "#22c55e",
                                }
                              : {
                                  background: "rgba(255,255,255,0.05)",
                                  color: "#9ca3af",
                                }
                          }
                        >
                          They owe me
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Error */}
            {error && <p className="text-red-400 text-sm">{error}</p>}

            {/* Submit */}
            <button
              onClick={handleSubmit}
              disabled={submitting}
              className="w-full py-4 rounded-xl font-semibold text-white transition-opacity disabled:opacity-50"
              style={{
                background: "linear-gradient(135deg, #6C63FF, #00D2FF)",
              }}
            >
              {submitting ? "Adding..." : "Add Transaction"}
            </button>
          </div>
        </div>
      )}
    </>
  );
}
