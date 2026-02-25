"use client";

import { useState, useEffect, useCallback } from "react";
import { Plus, X, Trash2, ChevronDown } from "lucide-react";
import api from "@/lib/api";
import { Account, Category, Merchant, Item } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";
import { showToast } from "@/components/ui/Toast";

type TransactionType = "expense" | "income" | "transfer";

interface LineItem {
  tempId: string;
  item_id: string;
  item_name: string;
  amount: string;
  quantity: string;
  remarks: string;
}

function nowDateTimeLocal() {
  const now = new Date();
  now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
  return now.toISOString().slice(0, 16);
}

export default function QuickAdd() {
  const [open, setOpen] = useState(false);
  const [type, setType] = useState<TransactionType>("expense");

  // items
  const [lineItems, setLineItems] = useState<LineItem[]>([]);
  const [itemSearch, setItemSearch] = useState("");
  const [itemSuggestions, setItemSuggestions] = useState<Item[]>([]);
  const [allItems, setAllItems] = useState<Item[]>([]);
  const [activeItemIndex, setActiveItemIndex] = useState<number | null>(null);

  // transaction fields
  const [accountId, setAccountId] = useState("");
  const [toAccountId, setToAccountId] = useState("");
  const [transferAmount, setTransferAmount] = useState("");
  const [merchantName, setMerchantName] = useState("");
  const [note, setNote] = useState("");
  const [status, setStatus] = useState<"completed" | "pending">("completed");
  const [customDate, setCustomDate] = useState(false);
  const [dateValue, setDateValue] = useState("");
  const [debtPerson, setDebtPerson] = useState("");
  const [debtDirection, setDebtDirection] = useState<"i_owe" | "they_owe">(
    "i_owe",
  );

  // data
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [filteredMerchants, setFilteredMerchants] = useState<Merchant[]>([]);

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const total = lineItems.reduce((sum, li) => {
    const amt = parseFloat(li.amount) || 0;
    const qty = parseFloat(li.quantity) || 1;
    return sum + amt * qty;
  }, 0);

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

  async function fetchData() {
    try {
      const [accountsRes, categoriesRes, merchantsRes, itemsRes] =
        await Promise.all([
          api.get("/api/accounts"),
          api.get("/api/categories"),
          api.get("/api/merchants"),
          api.get("/api/items"),
        ]);
      setAccounts(accountsRes.data);
      setCategories(categoriesRes.data);
      setMerchants(merchantsRes.data);
      setAllItems(itemsRes.data);
      if (accountsRes.data.length > 0) setAccountId(accountsRes.data[0].id);
    } catch {
      showToast("error", "Could not load data");
    }
  }

  function reset() {
    setLineItems([]);
    setItemSearch("");
    setItemSuggestions([]);
    setActiveItemIndex(null);
    setAccountId(accounts[0]?.id ?? "");
    setToAccountId("");
    setTransferAmount("");
    setMerchantName("");
    setNote("");
    setStatus("completed");
    setType("expense");
    setCustomDate(false);
    setDateValue("");
    setDebtPerson("");
    setDebtDirection("i_owe");
    setError("");
  }

  function close() {
    setOpen(false);
    reset();
  }

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") close();
    }
    if (open) window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [open]);

  function addLineItem(item: Item) {
    setLineItems((prev) => [
      ...prev,
      {
        tempId: crypto.randomUUID(),
        item_id: item.id,
        item_name: item.name,
        amount: item.last_price > 0 ? item.last_price.toString() : "",
        quantity: "1",
        remarks: "",
      },
    ]);
    setItemSearch("");
    setItemSuggestions([]);
    setActiveItemIndex(null);
  }

  async function addNewItem(name: string) {
    try {
      const res = await api.post("/api/items", { name });
      addLineItem({ ...res.data, last_price: 0, usage_count: 0 });
    } catch {
      showToast("error", "Could not create item");
    }
  }

  function removeLineItem(tempId: string) {
    setLineItems((prev) => prev.filter((li) => li.tempId !== tempId));
  }

  function updateLineItem(
    tempId: string,
    field: keyof LineItem,
    value: string,
  ) {
    setLineItems((prev) =>
      prev.map((li) => (li.tempId === tempId ? { ...li, [field]: value } : li)),
    );
  }

  async function handleSubmit() {
    if (!accountId) {
      setError("Select an account");
      return;
    }
    if (type === "transfer") {
      if (!toAccountId) {
        setError("Select destination account");
        return;
      }
      if (!transferAmount || parseFloat(transferAmount) <= 0) {
        setError("Enter transfer amount");
        return;
      }
    } else {
      if (lineItems.length === 0) {
        setError("Add at least one item");
        return;
      }
      for (const li of lineItems) {
        if (!li.amount || parseFloat(li.amount) <= 0) {
          setError(`Enter amount for ${li.item_name}`);
          return;
        }
      }
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
        amount: type === "transfer" ? parseFloat(transferAmount) : total,
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
        if (merchantId) payload.merchant_id = merchantId;
      }

      const txRes = await api.post("/api/transactions", payload);

      // create transaction items
      if (type !== "transfer") {
        await Promise.all(
          lineItems.map((li) =>
            api.post(`/api/transactions/${txRes.data.id}/items`, {
              item_id: li.item_id,
              amount: parseFloat(li.amount),
              quantity: parseFloat(li.quantity) || 1,
              remarks: li.remarks || undefined,
            }),
          ),
        );
      }

      // create debt if pending
      if (status === "pending" && debtPerson.trim()) {
        await api.post("/api/debts", {
          transaction_id: txRes.data.id,
          person_name: debtPerson.trim(),
          direction: debtDirection,
        });
      }

      showToast("success", "Transaction added!");
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

  return (
    <>
      {/* Floating button */}
      <button
        onClick={() => setOpen(true)}
        className="fixed bottom-8 right-8 w-14 h-14 rounded-full flex items-center justify-center shadow-lg z-50 transition-all hover:scale-110"
        style={{
          background: "linear-gradient(135deg, #6C63FF, #00D2FF)",
          boxShadow: "0 8px 32px rgba(108,99,255,0.4)",
        }}
      >
        <Plus
          size={24}
          className="text-white"
          style={{
            transform: open ? "rotate(45deg)" : "none",
            transition: "transform 0.2s",
          }}
        />
      </button>

      {/* Full screen modal */}
      {open && (
        <div
          className="fixed inset-0 z-50 flex flex-col"
          style={{ background: "rgba(0,0,0,0.7)", backdropFilter: "blur(8px)" }}
        >
          <div
            className="relative flex flex-col w-full max-w-lg mx-auto my-auto rounded-3xl overflow-hidden"
            style={{
              background: "rgba(15,17,26,0.98)",
              border: "1px solid rgba(255,255,255,0.08)",
              maxHeight: "90vh",
            }}
          >
            {/* Fixed header */}
            <div
              className="flex items-center justify-between px-6 py-4 flex-shrink-0"
              style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}
            >
              <h2 className="text-lg font-bold text-white">Add Transaction</h2>
              <button
                onClick={close}
                className="text-gray-400 hover:text-white transition-colors p-1"
              >
                <X size={20} />
              </button>
            </div>

            {/* Scrollable content */}
            <div className="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-5">
              {/* Type selector */}
              <div
                className="flex rounded-2xl p-1 gap-1"
                style={{ background: "rgba(255,255,255,0.05)" }}
              >
                {(["expense", "income", "transfer"] as TransactionType[]).map(
                  (t) => (
                    <button
                      key={t}
                      onClick={() => {
                        setType(t);
                        setLineItems([]);
                      }}
                      className="flex-1 py-2.5 rounded-xl text-sm font-semibold capitalize transition-all"
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
                              boxShadow: `0 4px 12px ${t === "expense" ? "rgba(239,68,68,0.3)" : t === "income" ? "rgba(34,197,94,0.3)" : "rgba(108,99,255,0.3)"}`,
                            }
                          : { color: "#6b7280" }
                      }
                    >
                      {t}
                    </button>
                  ),
                )}
              </div>

              {/* Transfer amount (only for transfers) */}
              {type === "transfer" ? (
                <div className="flex flex-col gap-4">
                  <div>
                    <label className="text-xs text-gray-500 mb-2 block">
                      Amount
                    </label>
                    <div
                      className="flex items-center gap-2 rounded-2xl px-5 py-4"
                      style={{ background: "rgba(255,255,255,0.05)" }}
                    >
                      <span className="text-gray-400 text-xl">₹</span>
                      <input
                        type="number"
                        placeholder="0.00"
                        value={transferAmount}
                        onChange={(e) => setTransferAmount(e.target.value)}
                        className="flex-1 bg-transparent text-white text-3xl font-bold outline-none placeholder-gray-800"
                        autoFocus
                      />
                    </div>
                  </div>
                  <div>
                    <label className="text-xs text-gray-500 mb-2 block">
                      From Account
                    </label>
                    <select
                      value={accountId}
                      onChange={(e) => setAccountId(e.target.value)}
                      className="w-full rounded-2xl px-4 py-3 text-white text-sm outline-none"
                      style={{ background: "rgba(255,255,255,0.05)" }}
                    >
                      {accounts.map((a) => (
                        <option
                          key={a.id}
                          value={a.id}
                          style={{ background: "#1a1d2e" }}
                        >
                          {a.name} — {formatCurrency(a.balance)}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="text-xs text-gray-500 mb-2 block">
                      To Account
                    </label>
                    <select
                      value={toAccountId}
                      onChange={(e) => setToAccountId(e.target.value)}
                      className="w-full rounded-2xl px-4 py-3 text-white text-sm outline-none"
                      style={{ background: "rgba(255,255,255,0.05)" }}
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
                </div>
              ) : (
                <>
                  {/* Items section */}
                  <div>
                    <div className="flex items-center justify-between mb-3">
                      <label className="text-xs text-gray-500 uppercase tracking-wider font-semibold">
                        Items
                      </label>
                      {lineItems.length > 0 && (
                        <span className="text-xs text-gray-600">
                          {lineItems.length} item
                          {lineItems.length !== 1 ? "s" : ""}
                        </span>
                      )}
                    </div>

                    {/* Line items */}
                    <div className="flex flex-col gap-2 mb-3">
                      {lineItems.map((li, idx) => (
                        <div
                          key={li.tempId}
                          className="rounded-2xl p-4 flex flex-col gap-3"
                          style={{
                            background: "rgba(255,255,255,0.04)",
                            border: "1px solid rgba(255,255,255,0.06)",
                          }}
                        >
                          {/* Item name + delete */}
                          <div className="flex items-center justify-between">
                            <p className="text-white text-sm font-semibold">
                              {li.item_name}
                            </p>
                            <button
                              onClick={() => removeLineItem(li.tempId)}
                              className="text-gray-600 hover:text-red-400 transition-colors"
                            >
                              <Trash2 size={14} />
                            </button>
                          </div>

                          {/* Amount + Quantity */}
                          <div className="grid grid-cols-2 gap-2">
                            <div>
                              <label className="text-xs text-gray-600 mb-1 block">
                                Amount
                              </label>
                              <div
                                className="flex items-center gap-1 rounded-xl px-3 py-2"
                                style={{ background: "rgba(255,255,255,0.05)" }}
                              >
                                <span className="text-gray-500 text-sm">₹</span>
                                <input
                                  type="number"
                                  placeholder="0.00"
                                  value={li.amount}
                                  onChange={(e) =>
                                    updateLineItem(
                                      li.tempId,
                                      "amount",
                                      e.target.value,
                                    )
                                  }
                                  className="bg-transparent text-white text-sm font-bold outline-none w-full placeholder-gray-700"
                                />
                              </div>
                            </div>
                            <div>
                              <label className="text-xs text-gray-600 mb-1 block">
                                Qty
                              </label>
                              <input
                                type="number"
                                placeholder="1"
                                value={li.quantity}
                                onChange={(e) =>
                                  updateLineItem(
                                    li.tempId,
                                    "quantity",
                                    e.target.value,
                                  )
                                }
                                className="w-full rounded-xl px-3 py-2 text-white text-sm outline-none placeholder-gray-700"
                                style={{ background: "rgba(255,255,255,0.05)" }}
                              />
                            </div>
                          </div>

                          {/* Remarks */}
                          <input
                            type="text"
                            placeholder="Remarks (optional)"
                            value={li.remarks}
                            onChange={(e) =>
                              updateLineItem(
                                li.tempId,
                                "remarks",
                                e.target.value,
                              )
                            }
                            className="w-full rounded-xl px-3 py-2 text-white text-sm outline-none placeholder-gray-700"
                            style={{ background: "rgba(255,255,255,0.05)" }}
                          />
                        </div>
                      ))}
                    </div>

                    {/* Add item input */}
                    <div className="relative">
                      <div
                        className="flex items-center gap-3 rounded-2xl px-4 py-3"
                        style={{
                          background: "rgba(255,255,255,0.04)",
                          border: "1px dashed rgba(255,255,255,0.1)",
                        }}
                      >
                        <Plus
                          size={16}
                          className="text-gray-600 flex-shrink-0"
                        />
                        <input
                          type="text"
                          placeholder="Add item..."
                          value={itemSearch}
                          onChange={(e) => setItemSearch(e.target.value)}
                          className="bg-transparent text-white text-sm outline-none flex-1 placeholder-gray-600"
                          onKeyDown={(e) => {
                            if (e.key === "Enter" && itemSearch.trim()) {
                              const match = allItems.find(
                                (i) =>
                                  i.name.toLowerCase() ===
                                  itemSearch.toLowerCase(),
                              );
                              if (match) addLineItem(match);
                              else addNewItem(itemSearch.trim());
                            }
                          }}
                        />
                      </div>

                      {/* Item suggestions */}
                      {itemSuggestions.length > 0 && (
                        <div
                          className="absolute top-full left-0 right-0 rounded-2xl mt-1 overflow-hidden z-10"
                          style={{
                            background: "#1a1d2e",
                            border: "1px solid rgba(255,255,255,0.1)",
                          }}
                        >
                          {itemSuggestions.map((item) => (
                            <button
                              key={item.id}
                              onMouseDown={(e) => {
                                e.preventDefault();
                                addLineItem(item);
                              }}
                              className="w-full text-left px-4 py-3 text-sm text-gray-300 hover:text-white hover:bg-white/5 transition-colors flex items-center justify-between"
                            >
                              <span>{item.name}</span>
                              <div className="flex items-center gap-3">
                                {item.last_price > 0 && (
                                  <span className="text-xs text-gray-500">
                                    {formatCurrency(item.last_price)}
                                  </span>
                                )}
                                {item.usage_count > 0 && (
                                  <span className="text-xs text-purple-400">
                                    {item.usage_count}x
                                  </span>
                                )}
                              </div>
                            </button>
                          ))}
                          {itemSearch.trim() &&
                            !allItems.find(
                              (i) =>
                                i.name.toLowerCase() ===
                                itemSearch.toLowerCase(),
                            ) && (
                              <button
                                onMouseDown={(e) => {
                                  e.preventDefault();
                                  addNewItem(itemSearch.trim());
                                }}
                                className="w-full text-left px-4 py-3 text-sm text-purple-400 hover:bg-white/5 transition-colors border-t"
                                style={{
                                  borderColor: "rgba(255,255,255,0.06)",
                                }}
                              >
                                + Create "{itemSearch.trim()}"
                              </button>
                            )}
                        </div>
                      )}

                      {/* Show create option when no suggestions but has input */}
                      {itemSearch.trim() && itemSuggestions.length === 0 && (
                        <div
                          className="absolute top-full left-0 right-0 rounded-2xl mt-1 overflow-hidden z-10"
                          style={{
                            background: "#1a1d2e",
                            border: "1px solid rgba(255,255,255,0.1)",
                          }}
                        >
                          <button
                            onMouseDown={(e) => {
                              e.preventDefault();
                              addNewItem(itemSearch.trim());
                            }}
                            className="w-full text-left px-4 py-3 text-sm text-purple-400 hover:bg-white/5 transition-colors"
                          >
                            + Create "{itemSearch.trim()}"
                          </button>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Total */}
                  {lineItems.length > 0 && (
                    <div
                      className="flex items-center justify-between rounded-2xl px-5 py-4"
                      style={{
                        background: "rgba(108,99,255,0.08)",
                        border: "1px solid rgba(108,99,255,0.15)",
                      }}
                    >
                      <span className="text-gray-400 text-sm font-medium">
                        Total
                      </span>
                      <span className="text-white text-2xl font-bold">
                        {formatCurrency(total)}
                      </span>
                    </div>
                  )}

                  {/* Account + Merchant */}
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="text-xs text-gray-500 mb-2 block">
                        Account
                      </label>
                      <select
                        value={accountId}
                        onChange={(e) => setAccountId(e.target.value)}
                        className="w-full rounded-2xl px-3 py-3 text-white text-sm outline-none"
                        style={{ background: "rgba(255,255,255,0.05)" }}
                      >
                        {accounts.map((a) => (
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

                    <div className="relative">
                      <label className="text-xs text-gray-500 mb-2 block">
                        Merchant
                      </label>
                      <input
                        type="text"
                        placeholder="e.g. Swiggy"
                        value={merchantName}
                        onChange={(e) => setMerchantName(e.target.value)}
                        className="w-full rounded-2xl px-3 py-3 text-white text-sm outline-none placeholder-gray-700"
                        style={{ background: "rgba(255,255,255,0.05)" }}
                      />
                      {filteredMerchants.length > 0 && (
                        <div
                          className="absolute top-full left-0 right-0 rounded-2xl mt-1 overflow-hidden z-10"
                          style={{
                            background: "#1a1d2e",
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
                              className="w-full text-left px-3 py-2 text-sm text-gray-300 hover:text-white hover:bg-white/5 transition-colors"
                            >
                              {m.name}
                            </button>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Date + Note */}
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <div className="flex items-center justify-between mb-2">
                        <label className="text-xs text-gray-500">Date</label>
                        <button
                          onClick={() => {
                            setCustomDate(!customDate);
                            if (!customDate) setDateValue(nowDateTimeLocal());
                          }}
                          className="w-8 h-4 rounded-full transition-colors relative flex-shrink-0"
                          style={{
                            background: customDate
                              ? "#6C63FF"
                              : "rgba(255,255,255,0.1)",
                          }}
                        >
                          <div
                            className="absolute top-0.5 w-3 h-3 rounded-full bg-white transition-all"
                            style={{ left: customDate ? "1rem" : "0.125rem" }}
                          />
                        </button>
                      </div>
                      {customDate ? (
                        <input
                          type="datetime-local"
                          value={dateValue}
                          onChange={(e) => setDateValue(e.target.value)}
                          className="w-full rounded-2xl px-3 py-3 text-white text-xs outline-none"
                          style={{
                            background: "rgba(255,255,255,0.05)",
                            colorScheme: "dark",
                          }}
                        />
                      ) : (
                        <div
                          className="rounded-2xl px-3 py-3 text-gray-600 text-xs"
                          style={{ background: "rgba(255,255,255,0.03)" }}
                        >
                          Now
                        </div>
                      )}
                    </div>

                    <div>
                      <label className="text-xs text-gray-500 mb-2 block">
                        Remarks
                      </label>
                      <input
                        type="text"
                        placeholder="Overall note..."
                        value={note}
                        onChange={(e) => setNote(e.target.value)}
                        className="w-full rounded-2xl px-3 py-3 text-white text-sm outline-none placeholder-gray-700"
                        style={{ background: "rgba(255,255,255,0.05)" }}
                      />
                    </div>
                  </div>

                  {/* Pending toggle */}
                  <div className="flex flex-col gap-3">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-sm text-white">Mark as pending</p>
                        <p className="text-xs text-gray-600">
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

                    {status === "pending" && (
                      <div
                        className="flex flex-col gap-3 rounded-2xl p-4"
                        style={{
                          background: "rgba(255,255,255,0.03)",
                          border: "1px solid rgba(255,255,255,0.06)",
                        }}
                      >
                        <p className="text-xs text-gray-500 font-medium uppercase tracking-wider">
                          Debt Details
                        </p>
                        <input
                          type="text"
                          placeholder="Person's name"
                          value={debtPerson}
                          onChange={(e) => setDebtPerson(e.target.value)}
                          className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none placeholder-gray-700"
                          style={{ background: "rgba(255,255,255,0.06)" }}
                        />
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
                    )}
                  </div>
                </>
              )}

              {/* Error */}
              {error && <p className="text-red-400 text-sm">{error}</p>}
            </div>

            {/* Fixed footer */}
            <div
              className="px-6 py-4 flex-shrink-0"
              style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}
            >
              <button
                onClick={handleSubmit}
                disabled={submitting}
                className="w-full py-4 rounded-2xl font-bold text-white text-base transition-opacity disabled:opacity-50"
                style={{
                  background: "linear-gradient(135deg, #6C63FF, #00D2FF)",
                  boxShadow: "0 8px 24px rgba(108,99,255,0.3)",
                }}
              >
                {submitting
                  ? "Adding..."
                  : type === "transfer"
                    ? `Transfer ${transferAmount ? formatCurrency(parseFloat(transferAmount)) : ""}`
                    : `Add ${lineItems.length > 0 ? formatCurrency(total) : ""}`}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
