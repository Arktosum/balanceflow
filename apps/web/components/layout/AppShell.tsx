"use client";

import { usePathname } from "next/navigation";
import Sidebar from "./Sidebar";
import AnimatedBackground from "@/components/ui/AnimatedBackground";
import QuickAdd from "@/components/ui/QuickAdd";
import ToastContainer from "@/components/ui/Toast";

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isLogin = pathname === "/login";

  return (
    <div className="flex min-h-screen">
      <AnimatedBackground />
      {!isLogin && <Sidebar />}
      <main className={isLogin ? "flex-1" : "flex-1 ml-56 p-8"}>
        {children}
      </main>
      {!isLogin && <QuickAdd />}
      {!isLogin && <ToastContainer />}
    </div>
  );
}
