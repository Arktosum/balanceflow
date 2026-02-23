"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { storeToken } from "@/lib/api";
import Logo from "@/components/ui/Logo";

export default function LoginPage() {
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function handleLogin() {
    if (!password.trim()) {
      setError("Enter your password");
      return;
    }

    setLoading(true);
    setError("");

    try {
      const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/health`, {
        headers: { "x-app-token": password },
      });

      if (res.ok) {
        await storeToken(password);

        router.replace("/");
      } else {
        setError("Wrong password. Try again.");
      }
    } catch {
      setError("Could not reach server. Try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#0f1117] relative overflow-hidden">
      {/* Background orbs */}
      <div
        style={{
          position: "fixed",
          inset: 0,
          zIndex: 0,
          overflow: "hidden",
          pointerEvents: "none",
        }}
      >
        <div
          style={{
            position: "absolute",
            width: 600,
            height: 600,
            top: "-20%",
            left: "-10%",
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(108,99,255,0.4) 0%, transparent 70%)",
            animation: "float1 8s ease-in-out infinite",
          }}
        />
        <div
          style={{
            position: "absolute",
            width: 500,
            height: 500,
            top: "40%",
            right: "-10%",
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(0,210,255,0.3) 0%, transparent 70%)",
            animation: "float2 10s ease-in-out infinite",
          }}
        />
        <style>{`
          @keyframes float1 {
            0%, 100% { transform: translate(0,0) scale(1); }
            33% { transform: translate(30px,-30px) scale(1.05); }
            66% { transform: translate(-20px,20px) scale(0.95); }
          }
          @keyframes float2 {
            0%, 100% { transform: translate(0,0) scale(1); }
            33% { transform: translate(-40px,20px) scale(1.08); }
            66% { transform: translate(20px,-30px) scale(0.95); }
          }
        `}</style>
      </div>

      {/* Login card */}
      <div
        className="relative z-10 w-full max-w-sm mx-4 rounded-3xl p-8 flex flex-col gap-6"
        style={{
          background: "rgba(255,255,255,0.04)",
          backdropFilter: "blur(20px)",
          border: "1px solid rgba(255,255,255,0.08)",
        }}
      >
        {/* Logo */}
        <div className="text-center">
          <Logo size="md" theme="dark" showText />
        </div>

        {/* Password input */}
        <div className="flex flex-col gap-2">
          <label className="text-xs text-gray-500">Password</label>
          <input
            type="password"
            placeholder="Enter your password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleLogin();
            }}
            autoFocus
            className="w-full rounded-xl px-4 py-3 text-white text-sm outline-none placeholder-gray-700"
            style={{
              background: "rgba(255,255,255,0.06)",
              border: "1px solid rgba(255,255,255,0.08)",
            }}
          />
          {error && <p className="text-red-400 text-xs">{error}</p>}
        </div>

        {/* Submit */}
        <button
          onClick={handleLogin}
          disabled={loading}
          className="w-full py-3 rounded-xl font-semibold text-white disabled:opacity-50 transition-opacity"
          style={{ background: "linear-gradient(135deg, #6C63FF, #00D2FF)" }}
        >
          {loading ? "Checking..." : "Enter"}
        </button>

        <p className="text-center text-gray-600 text-xs">Private access only</p>
      </div>
    </div>
  );
}
