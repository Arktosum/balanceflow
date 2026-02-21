export default function AnimatedBackground() {
  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: -1,
        overflow: "hidden",
        pointerEvents: "none",
        background: "#0f1117",
      }}
    >
      {/* Purple orb */}
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

      {/* Cyan orb */}
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

      {/* Red orb */}
      <div
        style={{
          position: "absolute",
          width: 400,
          height: 400,
          bottom: "-10%",
          left: "30%",
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(255,107,107,0.25) 0%, transparent 70%)",
          animation: "float3 12s ease-in-out infinite",
        }}
      />

      {/* Grid */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage: `
          linear-gradient(rgba(255,255,255,0.04) 1px, transparent 1px),
          linear-gradient(90deg, rgba(255,255,255,0.04) 1px, transparent 1px)
        `,
          backgroundSize: "40px 40px",
        }}
      />

      <style>{`
        @keyframes float1 {
          0%, 100% { transform: translate(0, 0) scale(1); }
          33% { transform: translate(30px, -30px) scale(1.05); }
          66% { transform: translate(-20px, 20px) scale(0.95); }
        }
        @keyframes float2 {
          0%, 100% { transform: translate(0, 0) scale(1); }
          33% { transform: translate(-40px, 20px) scale(1.08); }
          66% { transform: translate(20px, -30px) scale(0.95); }
        }
        @keyframes float3 {
          0%, 100% { transform: translate(0, 0) scale(1); }
          33% { transform: translate(20px, 30px) scale(1.05); }
          66% { transform: translate(-30px, -20px) scale(0.98); }
        }
      `}</style>
    </div>
  );
}
