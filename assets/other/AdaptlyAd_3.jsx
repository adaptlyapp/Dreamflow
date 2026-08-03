import { useCurrentFrame, interpolate, spring, Easing } from "remotion";

export const AdaptlyAd = () => {
  const frame = useCurrentFrame();
  const fps = 30;

  // ==========================================
  // SCENE TIMING
  // ==========================================
  const scene1Duration = 150; // 5s - Brand intro
  const scene2Start = scene1Duration;
  const scene2Duration = 180; // 6s - Problem
  const scene3Start = scene2Start + scene2Duration;
  const scene3Duration = 210; // 7s - Features
  const scene4Start = scene3Start + scene3Duration;
  const scene4Duration = 165; // 5.5s - Trust
  const scene5Start = scene4Start + scene4Duration;
  const scene5Duration = 195; // 6.5s - Stories
  const scene6Start = scene5Start + scene5Duration;

  // ==========================================
  // GLOBAL - AMBIENT / PARTICLES
  // ==========================================
  const ambientPulse = interpolate(frame, [0, 90, 180], [0.5, 1, 0.5], { extrapolateRight: "wrap" });
  const p1 = interpolate(frame, [0, 120, 240, 360], [0, -40, 0, -40], { extrapolateRight: "wrap" });
  const p2 = interpolate(frame, [0, 150, 300, 450], [0, 50, 0, 50], { extrapolateRight: "wrap" });
  const p3 = interpolate(frame, [0, 80, 160, 240], [0, -25, 0, -25], { extrapolateRight: "wrap" });
  const p4 = interpolate(frame, [0, 110, 220, 330], [0, 35, 0, 35], { extrapolateRight: "wrap" });
  const p5 = interpolate(frame, [0, 95, 190, 285], [0, -30, 0, -30], { extrapolateRight: "wrap" });

  // Scanline sweep
  const scanline = interpolate(frame, [0, 300], [-100, 1200], { extrapolateRight: "wrap" });

  // ==========================================
  // SCENE 1 — BRAND INTRO
  // ==========================================
  const s1out = interpolate(frame, [scene2Start - 30, scene2Start], [1, 0], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
    easing: Easing.in(Easing.cubic),
  });
  const logoEntryProgress = interpolate(frame, [0, 60], [0, 1], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const logoY = interpolate(frame, [0, 60], [120, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.5)),
  });
  const logoPerspX = interpolate(frame, [0, 60], [25, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const logoScale1 = spring({ frame, fps, config: { damping: 22, stiffness: 55, mass: 1.5 } });
  const logoGlow1 = interpolate(frame, [20, 70], [0, 1], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const tagX = interpolate(frame, [45, 85], [-80, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const tagOpacity = interpolate(frame, [45, 85], [0, 1], { extrapolateRight: "clamp" });
  const subX = interpolate(frame, [65, 100], [80, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const subOpacity = interpolate(frame, [65, 100], [0, 1], { extrapolateRight: "clamp" });
  const underlineW = interpolate(frame, [30, 80], [0, 100], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const orbitAngle = interpolate(frame, [0, 300], [0, 360], { extrapolateRight: "wrap" });

  // ==========================================
  // SCENE 1→2: flip wipe
  // ==========================================
  const flipProgress = interpolate(frame, [scene2Start - 30, scene2Start + 5], [0, 1], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  // ==========================================
  // SCENE 2 — PROBLEM
  // ==========================================
  const s2opacity = interpolate(
    frame,
    [scene2Start - 5, scene2Start + 20, scene2Start + scene2Duration - 30, scene2Start + scene2Duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const warnScale = spring({ frame: frame - scene2Start, fps, config: { damping: 12, stiffness: 150, mass: 0.8 } });
  const warnRotate = interpolate(frame, [scene2Start, scene2Start + 25], [-20, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.back(2)),
  });
  const probX = interpolate(frame, [scene2Start + 10, scene2Start + 50], [-120, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const probY2 = interpolate(frame, [scene2Start + 10, scene2Start + 50], [40, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const probSkew = interpolate(frame, [scene2Start + 10, scene2Start + 50], [-8, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const statZoom = spring({ frame: frame - (scene2Start + 35), fps, config: { damping: 18, stiffness: 80, mass: 1.2 } });
  const statReveal = interpolate(frame, [scene2Start + 35, scene2Start + 65], [0, 1], { extrapolateRight: "clamp" });
  const statPulse = interpolate(frame, [0, 40, 80], [1, 1.15, 1], { extrapolateRight: "wrap" });
  const sub1Reveal = interpolate(frame, [scene2Start + 55, scene2Start + 80], [0, 1], { extrapolateRight: "clamp" });
  const sub2Reveal = interpolate(frame, [scene2Start + 70, scene2Start + 95], [0, 1], { extrapolateRight: "clamp" });
  const sub1X = interpolate(frame, [scene2Start + 55, scene2Start + 80], [60, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const sub2X = interpolate(frame, [scene2Start + 70, scene2Start + 95], [60, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });

  // ==========================================
  // SCENE 2→3: vertical slice
  // ==========================================
  const sliceProgress = interpolate(frame, [scene3Start - 25, scene3Start + 5], [0, 1], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  // ==========================================
  // SCENE 3 — FEATURES
  // ==========================================
  const s3opacity = interpolate(
    frame,
    [scene3Start - 5, scene3Start + 15, scene3Start + scene3Duration - 30, scene3Start + scene3Duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const s3LogoY = interpolate(frame, [scene3Start, scene3Start + 40], [-80, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.5)),
  });
  const s3LogoOpacity = interpolate(frame, [scene3Start, scene3Start + 40], [0, 1], { extrapolateRight: "clamp" });
  const s3LogoRotate = interpolate(frame, [scene3Start, scene3Start + 40], [-12, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.5)),
  });
  const headY3 = interpolate(frame, [scene3Start + 20, scene3Start + 55], [50, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const headOpacity3 = interpolate(frame, [scene3Start + 20, scene3Start + 55], [0, 1], { extrapolateRight: "clamp" });
  const headPerspY = interpolate(frame, [scene3Start + 20, scene3Start + 55], [20, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const c1x = interpolate(frame, [scene3Start + 40, scene3Start + 75], [-200, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.2)),
  });
  const c1opacity = interpolate(frame, [scene3Start + 40, scene3Start + 75], [0, 1], { extrapolateRight: "clamp" });
  const c1rotateY = interpolate(frame, [scene3Start + 40, scene3Start + 75], [-25, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const c2x = interpolate(frame, [scene3Start + 65, scene3Start + 100], [200, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.2)),
  });
  const c2opacity = interpolate(frame, [scene3Start + 65, scene3Start + 100], [0, 1], { extrapolateRight: "clamp" });
  const c2rotateY = interpolate(frame, [scene3Start + 65, scene3Start + 100], [25, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const c3y = interpolate(frame, [scene3Start + 90, scene3Start + 130], [150, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const c3opacity = interpolate(frame, [scene3Start + 90, scene3Start + 130], [0, 1], { extrapolateRight: "clamp" });
  const c3scale = spring({ frame: frame - (scene3Start + 90), fps, config: { damping: 20, stiffness: 70 } });
  const icon1R = interpolate(frame, [scene3Start + 40, scene3Start + 75], [-20, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(2)) });
  const icon2R = interpolate(frame, [scene3Start + 65, scene3Start + 100], [20, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(2)) });
  const icon3R = interpolate(frame, [scene3Start + 90, scene3Start + 130], [-20, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(2)) });

  // ==========================================
  // SCENE 3→4: zoom burst
  // ==========================================
  const burstScale = interpolate(frame, [scene4Start - 20, scene4Start], [1, 8], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
    easing: Easing.in(Easing.cubic),
  });
  const burstOpacity = interpolate(frame, [scene4Start - 20, scene4Start], [0, 1], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
  });

  // ==========================================
  // SCENE 4 — TRUST
  // ==========================================
  const s4opacity = interpolate(
    frame,
    [scene4Start, scene4Start + 20, scene4Start + scene4Duration - 30, scene4Start + scene4Duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const shieldS = spring({ frame: frame - (scene4Start + 10), fps, config: { damping: 28, stiffness: 40, mass: 2 } });
  const shieldGlow4 = interpolate(frame, [scene4Start + 10, scene4Start + 60], [0, 1], { extrapolateRight: "clamp" });
  const shieldRotate = interpolate(frame, [scene4Start + 10, scene4Start + 60], [180, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const trustY4 = interpolate(frame, [scene4Start + 20, scene4Start + 65], [70, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const trust2Y4 = interpolate(frame, [scene4Start + 35, scene4Start + 80], [70, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const b1scale = spring({ frame: frame - (scene4Start + 60), fps, config: { damping: 12, stiffness: 180, mass: 0.6 } });
  const b2scale = spring({ frame: frame - (scene4Start + 80), fps, config: { damping: 12, stiffness: 180, mass: 0.6 } });
  const b1opacity = interpolate(frame, [scene4Start + 60, scene4Start + 80], [0, 1], { extrapolateRight: "clamp" });
  const b2opacity = interpolate(frame, [scene4Start + 80, scene4Start + 100], [0, 1], { extrapolateRight: "clamp" });

  // ==========================================
  // SCENE 4→5: diagonal wipe
  // ==========================================
  const diagWipe = interpolate(frame, [scene5Start - 25, scene5Start + 5], [0, 1], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  // ==========================================
  // SCENE 5 — STORIES
  // ==========================================
  const s5opacity = interpolate(
    frame,
    [scene5Start - 5, scene5Start + 20, scene5Start + scene5Duration - 30, scene5Start + scene5Duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const headW5 = interpolate(frame, [scene5Start + 10, scene5Start + 55], [0, 100], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const headOpacity5 = interpolate(frame, [scene5Start + 10, scene5Start + 30], [0, 1], { extrapolateRight: "clamp" });
  const card1x = interpolate(frame, [scene5Start + 25, scene5Start + 75], [-350, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const card1RotY = interpolate(frame, [scene5Start + 25, scene5Start + 75], [-30, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const card1Opacity = interpolate(frame, [scene5Start + 25, scene5Start + 55], [0, 1], { extrapolateRight: "clamp" });
  const card2x = interpolate(frame, [scene5Start + 50, scene5Start + 100], [350, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const card2RotY = interpolate(frame, [scene5Start + 50, scene5Start + 100], [30, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const card2Opacity = interpolate(frame, [scene5Start + 50, scene5Start + 80], [0, 1], { extrapolateRight: "clamp" });
  const bottomY5 = interpolate(frame, [scene5Start + 100, scene5Start + 140], [40, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const bottomOpacity5 = interpolate(frame, [scene5Start + 100, scene5Start + 140], [0, 1], { extrapolateRight: "clamp" });

  // ==========================================
  // SCENE 5→6: white flash
  // ==========================================
  const flashOpacity = interpolate(frame, [scene6Start - 15, scene6Start - 5, scene6Start + 10], [0, 1, 0], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
  });

  // ==========================================
  // SCENE 6 — FINAL CTA
  // ==========================================
  const s6opacity = interpolate(frame, [scene6Start - 5, scene6Start + 20], [0, 1], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
  });
  const heartScale6 = spring({ frame: frame - scene6Start, fps, config: { damping: 18, stiffness: 70, mass: 1.3 } });
  const heartbeat = interpolate(frame, [0, 45, 90], [1, 1.08, 1], { extrapolateRight: "wrap" });
  const glowPulse = interpolate(frame, [0, 55, 110], [0.5, 1, 0.5], { extrapolateRight: "wrap" });
  const headline6Y = interpolate(frame, [scene6Start + 10, scene6Start + 50], [60, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.3)),
  });
  const headline6Opacity = interpolate(frame, [scene6Start + 10, scene6Start + 50], [0, 1], { extrapolateRight: "clamp" });
  const sub6Y = interpolate(frame, [scene6Start + 30, scene6Start + 65], [40, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const sub6Opacity = interpolate(frame, [scene6Start + 30, scene6Start + 65], [0, 1], { extrapolateRight: "clamp" });
  const cta6Scale = spring({ frame: frame - (scene6Start + 50), fps, config: { damping: 15, stiffness: 140, mass: 0.8 } });
  const cta6Opacity = interpolate(frame, [scene6Start + 50, scene6Start + 75], [0, 1], { extrapolateRight: "clamp" });
  const tag6Opacity = interpolate(frame, [scene6Start + 80, scene6Start + 110], [0, 1], { extrapolateRight: "clamp" });

  return (
    <div style={{
      flex: 1,
      backgroundColor: "#070a12",
      backgroundImage: `
        radial-gradient(ellipse 900px 700px at 20% 30%, rgba(16, 185, 129, 0.13) 0%, transparent 55%),
        radial-gradient(ellipse 700px 600px at 80% 70%, rgba(59, 130, 246, 0.10) 0%, transparent 55%),
        radial-gradient(ellipse 600px 500px at 55% 95%, rgba(99, 102, 241, 0.07) 0%, transparent 50%)
      `,
      position: "relative",
      overflow: "hidden",
    }}>

      {/* GRAIN */}
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 512 512' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.75' numOctaves='4'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='0.03'/%3E%3C/svg%3E")`,
        mixBlendMode: "overlay", opacity: 0.7,
      }} />

      {/* SCANLINE */}
      <div style={{
        position: "absolute", left: 0, right: 0,
        top: scanline, height: 3,
        background: "linear-gradient(90deg, transparent, rgba(16,185,129,0.15), transparent)",
        pointerEvents: "none",
      }} />

      {/* PARTICLES */}
      {[
        { top: "18%", left: "12%", size: 9, color: "16, 185, 129", offset: p1 },
        { top: "62%", right: "18%", size: 13, color: "59, 130, 246", offset: p2 },
        { top: "33%", right: "10%", size: 6, color: "16, 185, 129", offset: p3 },
        { bottom: "22%", left: "22%", size: 11, color: "99, 102, 241", offset: p4 },
        { top: "75%", left: "45%", size: 7, color: "251, 191, 36", offset: p5 },
        { top: "10%", right: "35%", size: 5, color: "59, 130, 246", offset: p1 },
      ].map((p, i) => (
        <div key={i} style={{
          position: "absolute",
          top: p.top, left: p.left, right: p.right, bottom: p.bottom,
          width: p.size, height: p.size,
          borderRadius: "50%",
          backgroundColor: `rgba(${p.color}, 0.5)`,
          transform: `translateY(${p.offset}px)`,
          boxShadow: `0 0 ${p.size * 3}px rgba(${p.color}, 0.7)`,
          opacity: 0.85 * ambientPulse,
        }} />
      ))}

      {/* AMBIENT SWEEP */}
      <div style={{
        position: "absolute", inset: 0,
        background: `linear-gradient(135deg, rgba(16,185,129,${0.07 * ambientPulse}) 0%, transparent 40%, rgba(59,130,246,${0.05 * ambientPulse}) 100%)`,
        pointerEvents: "none",
      }} />

      {/* ══ SCENE 1: BRAND INTRO ══ */}
      {frame < scene2Start && (
        <div style={{
          position: "absolute", inset: 0,
          display: "flex", flexDirection: "column",
          justifyContent: "center", alignItems: "center",
          opacity: s1out,
          perspective: "1200px",
        }}>
          {/* Orbit rings */}
          <div style={{
            position: "absolute",
            width: 500, height: 500, borderRadius: "50%",
            border: "1px solid rgba(16,185,129,0.15)",
            transform: `rotate(${orbitAngle}deg)`,
            opacity: logoEntryProgress,
          }}>
            <div style={{
              position: "absolute", top: -6, left: "50%",
              width: 12, height: 12, borderRadius: "50%",
              backgroundColor: "rgba(16,185,129,0.8)",
              boxShadow: "0 0 20px rgba(16,185,129,1)",
              transform: "translateX(-50%)",
            }} />
          </div>
          <div style={{
            position: "absolute",
            width: 350, height: 350, borderRadius: "50%",
            border: "1px solid rgba(59,130,246,0.1)",
            transform: `rotate(${-orbitAngle * 1.3}deg)`,
            opacity: logoEntryProgress,
          }}>
            <div style={{
              position: "absolute", bottom: -5, left: "50%",
              width: 10, height: 10, borderRadius: "50%",
              backgroundColor: "rgba(59,130,246,0.7)",
              boxShadow: "0 0 15px rgba(59,130,246,0.9)",
              transform: "translateX(-50%)",
            }} />
          </div>

          {/* Logo */}
          <div style={{
            transform: `translateY(${logoY}px) scale(${logoScale1}) rotateX(${logoPerspX}deg)`,
            opacity: logoEntryProgress,
            position: "relative", marginBottom: 35,
          }}>
            <div style={{
              fontSize: 148,
              fontFamily: "'Epilogue', 'system-ui', sans-serif",
              fontWeight: 800,
              background: "linear-gradient(135deg, #10b981 0%, #34d399 40%, #3b82f6 100%)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
              backgroundClip: "text",
              letterSpacing: "-0.03em",
              filter: `drop-shadow(0 0 ${60 * logoGlow1}px rgba(16,185,129,${0.9 * logoGlow1}))`,
            }}>Adaptly</div>
            <div style={{
              position: "absolute", bottom: -8, left: 0,
              height: 5, width: `${underlineW}%`,
              background: "linear-gradient(90deg, #10b981, #3b82f6)",
              borderRadius: 3,
              boxShadow: "0 0 25px rgba(16,185,129,0.8)",
            }} />
          </div>

          {/* Tagline — slides from left */}
          <div style={{
            fontSize: 50,
            fontFamily: "'DM Sans', sans-serif",
            fontWeight: 600, color: "#10b981",
            transform: `translateX(${tagX}px)`,
            opacity: tagOpacity,
            letterSpacing: "0.01em", textAlign: "center",
            marginBottom: 20,
            textShadow: "0 0 40px rgba(16,185,129,0.4)",
          }}>
            Your guide to recovery and beyond
          </div>

          {/* Sub — slides from right */}
          <div style={{
            fontSize: 32,
            fontFamily: "'DM Sans', sans-serif",
            fontWeight: 400, color: "rgba(255,255,255,0.7)",
            transform: `translateX(${subX}px)`,
            opacity: subOpacity,
            textAlign: "center", lineHeight: 1.5,
          }}>
            Post-discharge recovery guidance + tracking<br />
            <span style={{ color: "rgba(255,255,255,0.45)", fontSize: 26 }}>for rehab and care teams</span>
          </div>
        </div>
      )}

      {/* TRANSITION 1→2: colour flash */}
      {frame >= scene2Start - 30 && frame < scene2Start + 5 && (
        <div style={{
          position: "absolute", inset: 0,
          background: "linear-gradient(135deg, #10b981, #3b82f6)",
          opacity: flipProgress * 0.3,
        }} />
      )}

      {/* ══ SCENE 2: PROBLEM ══ */}
      {frame >= scene2Start && frame < scene3Start && (
        <div style={{
          position: "absolute", inset: 0,
          display: "flex", flexDirection: "column",
          justifyContent: "center", alignItems: "center",
          opacity: s2opacity, padding: "80px 100px", gap: 45,
          perspective: "1000px",
        }}>
          {/* Warning icon — punch in with rotation */}
          <div style={{
            transform: `scale(${warnScale}) rotate(${warnRotate}deg)`,
            opacity: Math.min(warnScale, 1),
          }}>
            <svg width="95" height="95" viewBox="0 0 90 90"
              style={{ filter: "drop-shadow(0 0 30px rgba(251,191,36,0.8))" }}>
              <circle cx="45" cy="45" r="40" fill="none" stroke="#fbbf24" strokeWidth="4" />
              <path d="M 45 20 L 45 50" stroke="#fbbf24" strokeWidth="6" strokeLinecap="round" />
              <circle cx="45" cy="65" r="5" fill="#fbbf24" />
            </svg>
          </div>

          {/* Problem — diagonal skew slide */}
          <div style={{
            fontSize: 60,
            fontFamily: "'DM Sans', sans-serif",
            fontWeight: 600, color: "white",
            textAlign: "center", lineHeight: 1.35,
            transform: `translateX(${probX}px) translateY(${probY2}px) skewX(${probSkew}deg)`,
            maxWidth: 1050,
          }}>
            After discharge, patients face a{" "}
            <span style={{ color: "#ef4444", fontWeight: 700 }}>critical gap</span>
          </div>

          {/* Stat — slow zoom with pulse rings */}
          <div style={{
            position: "relative",
            opacity: statReveal,
            transform: `scale(${statZoom * statPulse})`,
          }}>
            <div style={{
              position: "absolute", inset: -30, borderRadius: "50%",
              border: "2px solid rgba(251,191,36,0.3)",
              transform: `scale(${statPulse})`,
            }} />
            <div style={{
              position: "absolute", inset: -15, borderRadius: "50%",
              border: "2px solid rgba(251,191,36,0.2)",
              transform: `scale(${statPulse * 1.05})`,
            }} />
            <div style={{
              fontSize: 80,
              fontFamily: "'Epilogue', sans-serif",
              fontWeight: 800, color: "#fbbf24",
              textShadow: "0 0 60px rgba(251,191,36,0.7)",
            }}>65%</div>
          </div>

          {/* Staggered sub lines */}
          <div style={{
            transform: `translateX(${sub1X}px)`, opacity: sub1Reveal,
            fontSize: 42, fontFamily: "'DM Sans', sans-serif",
            fontWeight: 500, color: "rgba(255,255,255,0.88)",
            textAlign: "center", lineHeight: 1.4, maxWidth: 900,
          }}>
            of patients feel{" "}
            <span style={{ fontWeight: 700, color: "#fff" }}>confused and unsupported</span>
          </div>

          <div style={{
            transform: `translateX(${sub2X}px)`, opacity: sub2Reveal,
            fontSize: 28, fontFamily: "'DM Sans', sans-serif",
            fontWeight: 400, color: "rgba(255,255,255,0.55)",
            fontStyle: "italic", textAlign: "center",
          }}>
            Leading to preventable readmissions and slower recovery
          </div>
        </div>
      )}

      {/* TRANSITION 2→3: vertical colour slices */}
      {frame >= scene3Start - 25 && frame < scene3Start + 5 && (
        <>
          <div style={{
            position: "absolute", top: 0, bottom: 0, left: 0,
            width: `${sliceProgress * 50}%`,
            background: "linear-gradient(180deg, rgba(16,185,129,0.4), rgba(59,130,246,0.3))",
            opacity: 0.6,
          }} />
          <div style={{
            position: "absolute", top: 0, bottom: 0, right: 0,
            width: `${sliceProgress * 50}%`,
            background: "linear-gradient(180deg, rgba(59,130,246,0.3), rgba(16,185,129,0.4))",
            opacity: 0.6,
          }} />
        </>
      )}

      {/* ══ SCENE 3: FEATURES ══ */}
      {frame >= scene3Start && frame < scene4Start && (
        <div style={{
          position: "absolute", inset: 0,
          display: "flex", flexDirection: "column",
          justifyContent: "center", alignItems: "center",
          opacity: s3opacity, padding: "50px 80px",
          perspective: "1400px",
        }}>
          {/* Logo drops from above with spin */}
          <div style={{
            marginBottom: 20,
            transform: `translateY(${s3LogoY}px) rotate(${s3LogoRotate}deg)`,
            opacity: s3LogoOpacity,
          }}>
            <div style={{
              fontSize: 74,
              fontFamily: "'Epilogue', sans-serif",
              fontWeight: 800,
              background: "linear-gradient(135deg, #10b981 0%, #3b82f6 100%)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
              backgroundClip: "text",
              letterSpacing: "-0.02em",
              filter: "drop-shadow(0 0 30px rgba(16,185,129,0.6))",
            }}>Adaptly</div>
          </div>

          {/* Headline — perspective tilt */}
          <div style={{
            fontSize: 52,
            fontFamily: "'Epilogue', sans-serif",
            fontWeight: 700, color: "#10b981",
            textAlign: "center", marginBottom: 30,
            transform: `translateY(${headY3}px) rotateX(${headPerspY}deg)`,
            opacity: headOpacity3,
            textShadow: "0 0 35px rgba(16,185,129,0.5)",
          }}>Guides them home, safely</div>

          {/* Feature cards */}
          <div style={{ display: "flex", flexDirection: "column", gap: 20, width: "100%", maxWidth: 1100 }}>
            {/* Card 1 — from left with 3D rotate */}
            <div style={{
              display: "flex", alignItems: "center", gap: 24,
              backgroundColor: "rgba(16,185,129,0.08)",
              padding: "20px 34px", borderRadius: 18,
              border: "2px solid rgba(16,185,129,0.28)",
              transform: `translateX(${c1x}px) rotateY(${c1rotateY}deg)`,
              opacity: c1opacity,
              boxShadow: "0 8px 40px rgba(16,185,129,0.18)",
            }}>
              <div style={{ transform: `rotate(${icon1R}deg)`, flexShrink: 0 }}>
                <svg width="58" height="58" viewBox="0 0 70 70" style={{ filter: "drop-shadow(0 0 15px rgba(16,185,129,0.7))" }}>
                  <circle cx="35" cy="35" r="32" fill="none" stroke="#10b981" strokeWidth="3" />
                  <path d="M 20 35 L 30 45 L 50 25" stroke="#10b981" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round" fill="none" />
                </svg>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 34, fontFamily: "'DM Sans', sans-serif", fontWeight: 700, color: "#fff", marginBottom: 5 }}>AI-Powered Recovery Plans</div>
                <div style={{ fontSize: 21, fontFamily: "'DM Sans', sans-serif", color: "rgba(255,255,255,0.72)", lineHeight: 1.3 }}>Personalized milestones and education tailored to each patient's condition</div>
              </div>
            </div>

            {/* Card 2 — from right */}
            <div style={{
              display: "flex", alignItems: "center", gap: 24,
              backgroundColor: "rgba(59,130,246,0.08)",
              padding: "20px 34px", borderRadius: 18,
              border: "2px solid rgba(59,130,246,0.28)",
              transform: `translateX(${c2x}px) rotateY(${c2rotateY}deg)`,
              opacity: c2opacity,
              boxShadow: "0 8px 40px rgba(59,130,246,0.18)",
            }}>
              <div style={{ transform: `rotate(${icon2R}deg)`, flexShrink: 0 }}>
                <svg width="58" height="58" viewBox="0 0 70 70" style={{ filter: "drop-shadow(0 0 15px rgba(59,130,246,0.7))" }}>
                  <circle cx="20" cy="25" r="12" fill="none" stroke="#3b82f6" strokeWidth="3" />
                  <circle cx="50" cy="25" r="12" fill="none" stroke="#3b82f6" strokeWidth="3" />
                  <circle cx="35" cy="50" r="12" fill="none" stroke="#3b82f6" strokeWidth="3" />
                  <line x1="27" y1="31" x2="38" y2="44" stroke="#3b82f6" strokeWidth="3" strokeLinecap="round" />
                  <line x1="43" y1="31" x2="32" y2="44" stroke="#3b82f6" strokeWidth="3" strokeLinecap="round" />
                </svg>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 34, fontFamily: "'DM Sans', sans-serif", fontWeight: 700, color: "#fff", marginBottom: 5 }}>Real-Time Team Coordination</div>
                <div style={{ fontSize: 21, fontFamily: "'DM Sans', sans-serif", color: "rgba(255,255,255,0.72)", lineHeight: 1.3 }}>Seamless collaboration across clinicians and providers with instant updates</div>
              </div>
            </div>

            {/* Card 3 — rises from below */}
            <div style={{
              display: "flex", alignItems: "center", gap: 24,
              backgroundColor: "rgba(99,102,241,0.08)",
              padding: "20px 34px", borderRadius: 18,
              border: "2px solid rgba(99,102,241,0.28)",
              transform: `translateY(${c3y}px) scale(${c3scale})`,
              opacity: c3opacity,
              boxShadow: "0 8px 40px rgba(99,102,241,0.18)",
            }}>
              <div style={{ transform: `rotate(${icon3R}deg)`, flexShrink: 0 }}>
                <svg width="58" height="58" viewBox="0 0 70 70" style={{ filter: "drop-shadow(0 0 15px rgba(99,102,241,0.7))" }}>
                  <path d="M 35 10 L 15 20 L 15 40 C 15 52 35 60 35 60 C 35 60 55 52 55 40 L 55 20 Z" fill="none" stroke="#6366f1" strokeWidth="3" />
                  <path d="M 25 35 L 32 42 L 45 28" stroke="#6366f1" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" fill="none" />
                </svg>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 34, fontFamily: "'DM Sans', sans-serif", fontWeight: 700, color: "#fff", marginBottom: 5 }}>Enterprise-Grade Security</div>
                <div style={{ fontSize: 21, fontFamily: "'DM Sans', sans-serif", color: "rgba(255,255,255,0.72)", lineHeight: 1.3 }}>HIPAA-compliant with encryption, audit logging, and role-based access</div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TRANSITION 3→4: zoom burst from center */}
      {frame >= scene4Start - 20 && frame < scene4Start && (
        <div style={{
          position: "absolute", inset: 0,
          display: "flex", justifyContent: "center", alignItems: "center",
          pointerEvents: "none",
        }}>
          <div style={{
            width: 100, height: 100, borderRadius: "50%",
            background: "radial-gradient(circle, rgba(59,130,246,0.8), rgba(16,185,129,0.4))",
            transform: `scale(${burstScale})`,
            opacity: Math.max(0, burstOpacity * (1 - (burstScale - 1) / 7)),
          }} />
        </div>
      )}

      {/* ══ SCENE 4: TRUST ══ */}
      {frame >= scene4Start && frame < scene5Start && (
        <div style={{
          position: "absolute", inset: 0,
          display: "flex", flexDirection: "column",
          justifyContent: "center", alignItems: "center",
          opacity: s4opacity, padding: 100, gap: 50,
          perspective: "1200px",
        }}>
          {/* Shield — slow-motion spin in */}
          <div style={{
            transform: `scale(${shieldS}) rotate(${shieldRotate}deg)`,
            opacity: Math.min(shieldS, 1),
          }}>
            <svg width="115" height="115" viewBox="0 0 110 110"
              style={{ filter: `drop-shadow(0 0 ${40 * shieldGlow4}px rgba(59,130,246,${shieldGlow4}))` }}>
              <path d="M 55 10 L 20 25 L 20 55 C 20 75 55 90 55 90 C 55 90 90 75 90 55 L 90 25 Z"
                fill="none" stroke="#3b82f6" strokeWidth="4" />
              <path d="M 40 52 L 50 62 L 70 40"
                stroke="#3b82f6" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
            </svg>
          </div>

          {/* Headlines — slow float up */}
          <div style={{
            fontSize: 66, fontFamily: "'Epilogue', sans-serif",
            fontWeight: 700, color: "white",
            textAlign: "center", lineHeight: 1.3,
            transform: `translateY(${trustY4}px)`,
            maxWidth: 1000,
          }}>Trusted by healthcare teams</div>

          <div style={{
            fontSize: 74, fontFamily: "'Epilogue', sans-serif",
            fontWeight: 800, color: "#3b82f6",
            textAlign: "center",
            transform: `translateY(${trust2Y4}px)`,
            textShadow: "0 0 50px rgba(59,130,246,0.6)",
          }}>to reduce readmissions</div>

          {/* Badges — spring bounce in */}
          <div style={{ display: "flex", gap: 55, marginTop: 15 }}>
            {[
              { emoji: "🏥", label: "Hospital\nApproved", color: "16,185,129", s: b1scale, o: b1opacity },
              { emoji: "🔒", label: "HIPAA\nCompliant", color: "99,102,241", s: b2scale, o: b2opacity },
            ].map((b, i) => (
              <div key={i} style={{
                display: "flex", flexDirection: "column", alignItems: "center", gap: 14,
                transform: `scale(${b.s})`, opacity: b.o,
              }}>
                <div style={{
                  width: 90, height: 90, borderRadius: "50%",
                  backgroundColor: `rgba(${b.color},0.15)`,
                  border: `3px solid rgba(${b.color},0.45)`,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  fontSize: 42,
                  boxShadow: `0 0 30px rgba(${b.color},0.3)`,
                }}>{b.emoji}</div>
                <div style={{
                  fontSize: 25, fontFamily: "'DM Sans', sans-serif",
                  fontWeight: 600, color: "rgba(255,255,255,0.85)",
                  textAlign: "center", whiteSpace: "pre-line",
                }}>{b.label}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* TRANSITION 4→5: diagonal colour wipe */}
      {frame >= scene5Start - 25 && frame < scene5Start + 5 && (
        <div style={{
          position: "absolute", inset: 0,
          background: "linear-gradient(135deg, rgba(16,185,129,0.35) 0%, rgba(59,130,246,0.25) 100%)",
          clipPath: `polygon(0 0, ${diagWipe * 100}% 0, ${diagWipe * 100 - 30}% 100%, 0 100%)`,
          opacity: 0.8,
        }} />
      )}

      {/* ══ SCENE 5: STORIES ══ */}
      {frame >= scene5Start && frame < scene6Start && (
        <div style={{
          position: "absolute", inset: 0,
          display: "flex", flexDirection: "column",
          justifyContent: "center", alignItems: "center",
          opacity: s5opacity, padding: "70px 90px", gap: 45,
          perspective: "1400px",
        }}>
          {/* Headline — typewriter clip reveal */}
          <div style={{ overflow: "hidden", opacity: headOpacity5 }}>
            <div style={{
              fontSize: 64, fontFamily: "'Epilogue', sans-serif",
              fontWeight: 700, color: "white", textAlign: "center",
              clipPath: `inset(0 ${100 - headW5}% 0 0)`,
            }}>Real impact on real people</div>
          </div>

          {/* Story cards — 3D slide from sides */}
          <div style={{ display: "flex", gap: 40, width: "100%", maxWidth: 1250, justifyContent: "center" }}>
            {/* Patient */}
            <div style={{
              flex: 1,
              backgroundColor: "rgba(16,185,129,0.09)",
              padding: "32px 38px", borderRadius: 22,
              border: "2px solid rgba(16,185,129,0.32)",
              transform: `translateX(${card1x}px) rotateY(${card1RotY}deg)`,
              opacity: card1Opacity,
              boxShadow: "0 12px 50px rgba(16,185,129,0.22)",
            }}>
              <div style={{
                width: 68, height: 68, borderRadius: "50%",
                backgroundColor: "rgba(16,185,129,0.2)",
                border: "2px solid rgba(16,185,129,0.45)",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 36, marginBottom: 22,
                boxShadow: "0 0 25px rgba(16,185,129,0.3)",
              }}>❤️</div>
              <div style={{
                fontSize: 21, fontFamily: "'DM Sans', sans-serif",
                fontWeight: 600, color: "#10b981",
                marginBottom: 14, letterSpacing: "0.06em", textTransform: "uppercase",
              }}>Patient Perspective</div>
              <div style={{
                fontSize: 28, fontFamily: "'DM Sans', sans-serif",
                fontWeight: 500, color: "rgba(255,255,255,0.92)",
                lineHeight: 1.55, fontStyle: "italic",
              }}>"Finally felt supported at home. Clear milestones made recovery less overwhelming."</div>
              <div style={{
                fontSize: 20, fontFamily: "'DM Sans', sans-serif",
                fontWeight: 500, color: "rgba(255,255,255,0.55)", marginTop: 18,
              }}>— Sarah, recovering from surgery</div>
            </div>

            {/* Care team */}
            <div style={{
              flex: 1,
              backgroundColor: "rgba(59,130,246,0.09)",
              padding: "32px 38px", borderRadius: 22,
              border: "2px solid rgba(59,130,246,0.32)",
              transform: `translateX(${card2x}px) rotateY(${card2RotY}deg)`,
              opacity: card2Opacity,
              boxShadow: "0 12px 50px rgba(59,130,246,0.22)",
            }}>
              <div style={{
                width: 68, height: 68, borderRadius: "50%",
                backgroundColor: "rgba(59,130,246,0.2)",
                border: "2px solid rgba(59,130,246,0.45)",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 36, marginBottom: 22,
                boxShadow: "0 0 25px rgba(59,130,246,0.3)",
              }}>👨‍⚕️</div>
              <div style={{
                fontSize: 21, fontFamily: "'DM Sans', sans-serif",
                fontWeight: 600, color: "#3b82f6",
                marginBottom: 14, letterSpacing: "0.06em", textTransform: "uppercase",
              }}>Care Team Perspective</div>
              <div style={{
                fontSize: 28, fontFamily: "'DM Sans', sans-serif",
                fontWeight: 500, color: "rgba(255,255,255,0.92)",
                lineHeight: 1.55, fontStyle: "italic",
              }}>"Real-time updates keep our team aligned. We catch issues before they become readmissions."</div>
              <div style={{
                fontSize: 20, fontFamily: "'DM Sans', sans-serif",
                fontWeight: 500, color: "rgba(255,255,255,0.55)", marginTop: 18,
              }}>— Dr. Martinez, Physical Medicine</div>
            </div>
          </div>

          {/* Bottom line — gentle rise */}
          <div style={{
            fontSize: 32, fontFamily: "'DM Sans', sans-serif",
            fontWeight: 500, color: "rgba(255,255,255,0.65)",
            textAlign: "center",
            transform: `translateY(${bottomY5}px)`,
            opacity: bottomOpacity5,
          }}>Better coordination. Better outcomes.</div>
        </div>
      )}

      {/* TRANSITION 5→6: white flash */}
      <div style={{
        position: "absolute", inset: 0,
        backgroundColor: "white",
        opacity: flashOpacity,
        pointerEvents: "none",
      }} />

      {/* ══ SCENE 6: FINAL CTA ══ */}
      {frame >= scene6Start && (
        <div style={{
          position: "absolute", inset: 0,
          display: "flex", flexDirection: "column",
          justifyContent: "center", alignItems: "center",
          opacity: s6opacity, gap: 40,
        }}>
          {/* Heartbeat */}
          <div style={{ transform: `scale(${heartScale6 * heartbeat})` }}>
            <svg width="105" height="105" viewBox="0 0 100 100"
              style={{ filter: `drop-shadow(0 0 ${35 * glowPulse}px rgba(16,185,129,${glowPulse}))` }}>
              <path
                d="M50 85 C 20 60, 10 40, 10 28 C 10 15, 20 10, 28 10 C 36 10, 44 15, 50 25 C 56 15, 64 10, 72 10 C 80 10, 90 15, 90 28 C 90 40, 80 60, 50 85 Z"
                fill="#10b981" />
            </svg>
          </div>

          {/* Headline — springs up */}
          <div style={{
            fontSize: 70, fontFamily: "'Epilogue', sans-serif",
            fontWeight: 700, color: "white",
            textAlign: "center",
            transform: `translateY(${headline6Y}px)`,
            opacity: headline6Opacity,
            lineHeight: 1.25, maxWidth: 1050,
          }}>
            Better outcomes.<br />
            <span style={{ color: "#10b981" }}>Healthier patients.</span>
          </div>

          {/* Sub — floats up */}
          <div style={{
            fontSize: 36, fontFamily: "'DM Sans', sans-serif",
            fontWeight: 500, color: "rgba(255,255,255,0.78)",
            textAlign: "center", maxWidth: 900, lineHeight: 1.4,
            transform: `translateY(${sub6Y}px)`,
            opacity: sub6Opacity,
          }}>
            From hospital to home, we're with them every step
          </div>

          {/* CTA button — bounces in */}
          <div style={{
            marginTop: 10, padding: "22px 60px",
            fontSize: 36, fontFamily: "'Epilogue', sans-serif",
            fontWeight: 600, color: "#10b981",
            border: "2px solid #10b981", borderRadius: 18,
            transform: `scale(${cta6Scale})`,
            opacity: cta6Opacity,
            boxShadow: `0 0 50px rgba(16,185,129,${0.3 * glowPulse}), inset 0 0 30px rgba(16,185,129,${0.05 * glowPulse})`,
            backgroundColor: "rgba(16,185,129,0.1)",
            letterSpacing: "0.01em",
          }}>
            adaptlyapp.com
          </div>

          {/* Tagline */}
          <div style={{
            fontSize: 22, fontFamily: "'DM Sans', sans-serif",
            color: "rgba(255,255,255,0.45)",
            fontWeight: 400, textAlign: "center",
            opacity: tag6Opacity,
          }}>
            Empowering recovery through intelligent care coordination
          </div>
        </div>
      )}
    </div>
  );
};
