"use client";

import { clsx } from "clsx";
import { CSSProperties } from "react";

interface CardProps {
  children: React.ReactNode;
  className?: string;
  onClick?: () => void;
  style?: CSSProperties;
}

export default function Card({
  children,
  className,
  onClick,
  style,
}: CardProps) {
  return (
    <div
      onClick={onClick}
      style={{
        background: "rgba(255, 255, 255, 0.04)",
        backdropFilter: "blur(12px)",
        WebkitBackdropFilter: "blur(12px)",
        border: "1px solid rgba(255, 255, 255, 0.08)",
        ...style,
      }}
      className={clsx(
        "rounded-2xl p-4",
        onClick && "cursor-pointer transition-colors",
        className,
      )}
    >
      {children}
    </div>
  );
}
