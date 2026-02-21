import Sidebar from "./Sidebar";
import AnimatedBackground from "@/components/ui/AnimatedBackground";
import QuickAdd from "@/components/ui/QuickAdd";
import ToastContainer from "@/components/ui/Toast";

export default function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen">
      <AnimatedBackground />
      <Sidebar />
      <main className="flex-1 ml-56 p-8">{children}</main>
      <QuickAdd />
      <ToastContainer />
    </div>
  );
}
