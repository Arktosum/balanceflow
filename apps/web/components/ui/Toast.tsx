"use client";

import { useEffect, useState } from "react";
import { CheckCircle, XCircle, AlertCircle, X } from "lucide-react";

export type ToastType = "success" | "error" | "warning";

export interface ToastMessage {
  id: string;
  type: ToastType;
  message: string;
}

// Global event system so any component can trigger a toast
export function showToast(type: ToastType, message: string) {
  window.dispatchEvent(
    new CustomEvent("show-toast", {
      detail: { type, message, id: crypto.randomUUID() },
    }),
  );
}

function Toast({
  toast,
  onRemove,
}: {
  toast: ToastMessage;
  onRemove: (id: string) => void;
}) {
  useEffect(() => {
    const timer = setTimeout(() => onRemove(toast.id), 4000);
    return () => clearTimeout(timer);
  }, [toast.id, onRemove]);

  const config = {
    success: {
      icon: <CheckCircle size={18} />,
      color: "#22c55e",
      bg: "rgba(34,197,94,0.1)",
      border: "rgba(34,197,94,0.2)",
    },
    error: {
      icon: <XCircle size={18} />,
      color: "#ef4444",
      bg: "rgba(239,68,68,0.1)",
      border: "rgba(239,68,68,0.2)",
    },
    warning: {
      icon: <AlertCircle size={18} />,
      color: "#f59e0b",
      bg: "rgba(245,158,11,0.1)",
      border: "rgba(245,158,11,0.2)",
    },
  }[toast.type];

  return (
    <div
      className="flex items-center gap-3 px-4 py-3 rounded-xl shadow-lg min-w-[280px] max-w-sm"
      style={{
        background: config.bg,
        border: `1px solid ${config.border}`,
        backdropFilter: "blur(12px)",
        animation: "slideIn 0.2s ease-out",
      }}
    >
      <span style={{ color: config.color }}>{config.icon}</span>
      <p className="text-white text-sm flex-1">{toast.message}</p>
      <button
        onClick={() => onRemove(toast.id)}
        className="text-gray-500 hover:text-white transition-colors ml-2"
      >
        <X size={14} />
      </button>
    </div>
  );
}

export default function ToastContainer() {
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  useEffect(() => {
    function handler(e: Event) {
      const toast = (e as CustomEvent).detail as ToastMessage;
      setToasts((prev) => [...prev, toast]);
    }
    window.addEventListener("show-toast", handler);
    return () => window.removeEventListener("show-toast", handler);
  }, []);

  function remove(id: string) {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }

  return (
    <>
      <style>{`
        @keyframes slideIn {
          from { transform: translateX(100%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
      `}</style>
      <div className="fixed bottom-8 left-1/2 -translate-x-1/2 z-[100] flex flex-col gap-2 items-center">
        {toasts.map((toast) => (
          <Toast key={toast.id} toast={toast} onRemove={remove} />
        ))}
      </div>
    </>
  );
}
