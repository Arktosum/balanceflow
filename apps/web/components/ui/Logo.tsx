interface LogoProps {
  size?: "xs" | "sm" | "md" | "lg" | "xl" | number;
  theme?: "light" | "dark";
  showText?: boolean;
  className?: string;
}

export default function Logo({
  size = "md",
  theme = "dark",
  showText = false,
  className = "",
}: LogoProps) {
  const sizeMap = { xs: 32, sm: 48, md: 80, lg: 120, xl: 200 };
  const logoSize = typeof size === "number" ? size : sizeMap[size];

  const colors =
    theme === "dark"
      ? {
          gradient1Start: "#C084FC",
          gradient1End: "#E9D5FF",
          gradient2Start: "#E9D5FF",
          gradient2End: "#C084FC",
          centerStart: "#DDD6FE",
          centerEnd: "#C084FC",
        }
      : {
          gradient1Start: "#9333EA",
          gradient1End: "#C084FC",
          gradient2Start: "#C084FC",
          gradient2End: "#9333EA",
          centerStart: "#A855F7",
          centerEnd: "#7C3AED",
        };

  const id = `logo-${theme}-${logoSize}`;

  return (
    <div className={`flex flex-col items-center gap-3 ${className}`}>
      <svg
        width={logoSize}
        height={logoSize}
        viewBox="0 0 200 200"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M40 100 Q60 60, 80 80 T120 80 T160 100"
          stroke={`url(#g1-${id})`}
          strokeWidth="8"
          strokeLinecap="round"
          fill="none"
        />
        <path
          d="M40 100 Q60 140, 80 120 T120 120 T160 100"
          stroke={`url(#g2-${id})`}
          strokeWidth="8"
          strokeLinecap="round"
          fill="none"
        />
        <circle cx="100" cy="100" r="12" fill={`url(#g3-${id})`} />
        <defs>
          <linearGradient id={`g1-${id}`} x1="40" y1="80" x2="160" y2="80">
            <stop offset="0%" stopColor={colors.gradient1Start} />
            <stop offset="100%" stopColor={colors.gradient1End} />
          </linearGradient>
          <linearGradient id={`g2-${id}`} x1="40" y1="120" x2="160" y2="120">
            <stop offset="0%" stopColor={colors.gradient2Start} />
            <stop offset="100%" stopColor={colors.gradient2End} />
          </linearGradient>
          <linearGradient id={`g3-${id}`} x1="100" y1="88" x2="100" y2="112">
            <stop offset="0%" stopColor={colors.centerStart} />
            <stop offset="100%" stopColor={colors.centerEnd} />
          </linearGradient>
        </defs>
      </svg>

      {showText && (
        <div className="flex flex-col items-center gap-1">
          <h2
            className="text-2xl font-semibold tracking-tight"
            style={{
              background:
                theme === "dark"
                  ? "linear-gradient(to right, #c084fc, #e9d5ff, #c084fc)"
                  : "linear-gradient(to right, #9333ea, #c084fc, #9333ea)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
            }}
          >
            BalanceFlow
          </h2>
          <p
            className="text-sm tracking-wider"
            style={{ color: theme === "dark" ? "#c084fc" : "#9333ea" }}
          >
            Personal Finance Tracker
          </p>
        </div>
      )}
    </div>
  );
}
