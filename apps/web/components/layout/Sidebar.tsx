"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { clsx } from "clsx";
import {
  LayoutDashboard,
  ArrowLeftRight,
  PieChart,
  CreditCard,
  Tag,
  Store,
  Clock,
} from "lucide-react";

const navItems = [
  { href: "/", icon: LayoutDashboard, label: "Dashboard" },
  { href: "/transactions", icon: ArrowLeftRight, label: "Transactions" },
  { href: "/analytics", icon: PieChart, label: "Analytics" },
  { href: "/accounts", icon: CreditCard, label: "Accounts" },
  { href: "/debts", icon: Clock, label: "Debts" },
  { href: "/categories", icon: Tag, label: "Categories" },
  { href: "/merchants", icon: Store, label: "Merchants" },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside
      style={{
        background: "rgba(255, 255, 255, 0.03)",
        backdropFilter: "blur(20px)",
        WebkitBackdropFilter: "blur(20px)",
        borderRight: "1px solid rgba(255, 255, 255, 0.06)",
      }}
      className="fixed left-0 top-0 h-full w-56 flex flex-col"
    >
      {/* Logo */}
      <div className="p-6 border-b border-white/5">
        <div className="flex items-center gap-2">
          <span className="text-2xl">⚡</span>
          <span className="font-bold text-lg text-white">BalanceFlow</span>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 p-4 flex flex-col gap-1">
        {navItems.map(({ href, icon: Icon, label }) => (
          <Link
            key={href}
            href={href}
            className={clsx(
              "flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-colors",
              pathname === href
                ? "bg-[#6C63FF] text-white"
                : "text-gray-400 hover:text-white hover:bg-white/5",
            )}
          >
            <Icon size={18} />
            {label}
          </Link>
        ))}
      </nav>

      {/* Footer */}
      <div className="p-4 border-t border-white/5">
        <p className="text-xs text-gray-600 text-center">BalanceFlow v1.0</p>
      </div>
    </aside>
  );
}
