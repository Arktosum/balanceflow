"use client";

import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";

export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    if (pathname === "/login") {
      setAuthorized(true);
      return;
    }

    const token = localStorage.getItem("bf_token");
    if (!token) {
      router.replace("/login");
    } else {
      setAuthorized(true);
    }
  }, [pathname, router]);

  if (!authorized) return null;

  return <>{children}</>;
}
