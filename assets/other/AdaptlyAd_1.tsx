import { useCurrentFrame, interpolate, spring, Easing } from "remotion";

export const AdaptlyAd = () => {
  const frame = useCurrentFrame();
  const fps = 30;

  // ==========================================
  // SCENE TIMING
  // ==========================================
  const scene1Duration = 150;
  const scene2Start = scene1Duration;
  const scene2Duration = 180;
  const scene3Start = scene2Start + scene2Duration;
  const scene3Duration = 240;
  const scene4Start = scene3Start + scene3Duration;
  const scene4Duration = 165;
  const scene5Start = scene4Start + scene4Duration;
  const scene5Duration = 195;
  // NEW scenes
  const scene6Start = scene5Start + scene5Duration;
  const scene6Duration = 180;
  const scene7Start = scene6Start + scene6Duration;
  const scene7Duration = 180;
  const scene8Start = scene7Start + scene7Duration;
  const scene8Duration = 210;
  const scene9Start = scene8Start + scene8Duration;

  // ==========================================
  // GLOBAL
  // ==========================================
  const ambientPulse = interpolate(frame, [0, 90, 180], [0.5, 1, 0.5], { extrapolateRight: "wrap" });
  const p1 = interpolate(frame, [0, 120, 240, 360], [0, -40, 0, -40], { extrapolateRight: "wrap" });
  const p2 = interpolate(frame, [0, 150, 300, 450], [0, 50, 0, 50], { extrapolateRight: "wrap" });
  const p3 = interpolate(frame, [0, 80, 160, 240], [0, -25, 0, -25], { extrapolateRight: "wrap" });
  const p4 = interpolate(frame, [0, 110, 220, 330], [0, 35, 0, 35], { extrapolateRight: "wrap" });
  const scanline = interpolate(frame, [0, 300], [-100, 1200], { extrapolateRight: "wrap" });
  // Global rotating background
  const bgRotate = interpolate(frame, [0, 600], [0, 360], { extrapolateRight: "wrap" });
  // Extra floating particles
  const fp1 = interpolate(frame, [0, 200, 400], [0, -60, 0], { extrapolateRight: "wrap" });
  const fp2 = interpolate(frame, [0, 180, 360], [0, 45, 0], { extrapolateRight: "wrap" });
  const fp3 = interpolate(frame, [0, 250, 500], [0, -35, 0], { extrapolateRight: "wrap" });

  // ==========================================
  // SCENE 1 — BRAND INTRO
  // ==========================================
  const s1out = interpolate(frame, [scene2Start - 30, scene2Start], [1, 0], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.in(Easing.cubic),
  });
  const logoEntryProgress = interpolate(frame, [0, 60], [0, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const logoY1 = interpolate(frame, [0, 60], [120, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.5)) });
  const logoPerspX = interpolate(frame, [0, 60], [25, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const logoScale1 = spring({ frame, fps, config: { damping: 22, stiffness: 55, mass: 1.5 } });
  const logoGlow1 = interpolate(frame, [20, 70], [0, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const tagX = interpolate(frame, [45, 85], [-80, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const tagOpacity = interpolate(frame, [45, 85], [0, 1], { extrapolateRight: "clamp" });
  const subX = interpolate(frame, [65, 100], [80, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const subOpacity = interpolate(frame, [65, 100], [0, 1], { extrapolateRight: "clamp" });
  const underlineW = interpolate(frame, [30, 80], [0, 100], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const orbitAngle = interpolate(frame, [0, 300], [0, 360], { extrapolateRight: "wrap" });
  // NEW: DNA helix lines behind logo
  const helixOpacity = interpolate(frame, [10, 50], [0, 0.3], { extrapolateRight: "clamp" });
  const helixShift = interpolate(frame, [0, 150], [0, 40], { extrapolateRight: "wrap" });

  // ==========================================
  // SCENE 2 — PROBLEM
  // ==========================================
  const s2opacity = interpolate(frame,
    [scene2Start - 5, scene2Start + 20, scene2Start + scene2Duration - 30, scene2Start + scene2Duration],
    [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const warnScale = spring({ frame: frame - scene2Start, fps, config: { damping: 12, stiffness: 150, mass: 0.8 } });
  const warnRotate = interpolate(frame, [scene2Start, scene2Start + 25], [-20, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(2)) });
  const probX = interpolate(frame, [scene2Start + 10, scene2Start + 50], [-120, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const probY2 = interpolate(frame, [scene2Start + 10, scene2Start + 50], [40, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const probSkew = interpolate(frame, [scene2Start + 10, scene2Start + 50], [-8, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const statZoom = spring({ frame: frame - (scene2Start + 35), fps, config: { damping: 18, stiffness: 80, mass: 1.2 } });
  const statReveal = interpolate(frame, [scene2Start + 35, scene2Start + 65], [0, 1], { extrapolateRight: "clamp" });
  const statPulse = interpolate(frame, [0, 40, 80], [1, 1.15, 1], { extrapolateRight: "wrap" });
  const sub1Reveal = interpolate(frame, [scene2Start + 55, scene2Start + 80], [0, 1], { extrapolateRight: "clamp" });
  const sub2Reveal = interpolate(frame, [scene2Start + 70, scene2Start + 95], [0, 1], { extrapolateRight: "clamp" });
  const sub1X = interpolate(frame, [scene2Start + 55, scene2Start + 80], [60, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const sub2X = interpolate(frame, [scene2Start + 70, scene2Start + 95], [60, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  // NEW: ripple rings around the warning icon
  const ripple1 = interpolate(frame, [scene2Start + 20, scene2Start + 90], [0, 1], { extrapolateRight: "clamp" });
  const ripple2 = interpolate(frame, [scene2Start + 40, scene2Start + 110], [0, 1], { extrapolateRight: "clamp" });

  // ==========================================
  // SCENE 3 — FEATURES + iPHONE (fixed screen, more animations)
  // ==========================================
  const s3opacity = interpolate(frame,
    [scene3Start - 5, scene3Start + 15, scene3Start + scene3Duration - 30, scene3Start + scene3Duration],
    [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const phoneY = interpolate(frame, [scene3Start + 20, scene3Start + 90], [600, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const phoneRotate = interpolate(frame, [scene3Start + 20, scene3Start + 90], [18, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const phoneScale3 = spring({ frame: frame - (scene3Start + 20), fps, config: { damping: 26, stiffness: 50, mass: 1.8 } });
  const phoneOpacity = interpolate(frame, [scene3Start + 20, scene3Start + 55], [0, 1], { extrapolateRight: "clamp" });
  const phoneSway = interpolate(frame, [0, 120, 240], [0, 4, 0], { extrapolateRight: "wrap" });
  const phoneGlow = interpolate(frame, [scene3Start + 60, scene3Start + 100], [0, 1], { extrapolateRight: "clamp" });
  const s3LogoY = interpolate(frame, [scene3Start, scene3Start + 40], [-60, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.5)) });
  const s3LogoOpacity = interpolate(frame, [scene3Start, scene3Start + 40], [0, 1], { extrapolateRight: "clamp" });
  const headY3 = interpolate(frame, [scene3Start + 25, scene3Start + 60], [50, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const headOpacity3 = interpolate(frame, [scene3Start + 25, scene3Start + 60], [0, 1], { extrapolateRight: "clamp" });
  const f1o = interpolate(frame, [scene3Start + 70, scene3Start + 95], [0, 1], { extrapolateRight: "clamp" });
  const f1x = interpolate(frame, [scene3Start + 70, scene3Start + 95], [-50, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const f2o = interpolate(frame, [scene3Start + 90, scene3Start + 115], [0, 1], { extrapolateRight: "clamp" });
  const f2x = interpolate(frame, [scene3Start + 90, scene3Start + 115], [-50, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const f3o = interpolate(frame, [scene3Start + 110, scene3Start + 135], [0, 1], { extrapolateRight: "clamp" });
  const f3x = interpolate(frame, [scene3Start + 110, scene3Start + 135], [-50, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  // NEW: animated progress ring inside phone
  const progressArc = interpolate(frame, [scene3Start + 100, scene3Start + 200], [0, 270], { extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
  // Notification pop-in
  const notifScale = spring({ frame: frame - (scene3Start + 140), fps, config: { damping: 15, stiffness: 200, mass: 0.5 } });
  const notifOpacity = interpolate(frame, [scene3Start + 140, scene3Start + 160], [0, 1], { extrapolateRight: "clamp" });

  // ==========================================
  // SCENE 4 — TRUST
  // ==========================================
  const s4opacity = interpolate(frame,
    [scene4Start, scene4Start + 20, scene4Start + scene4Duration - 30, scene4Start + scene4Duration],
    [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const shieldS = spring({ frame: frame - (scene4Start + 10), fps, config: { damping: 28, stiffness: 40, mass: 2 } });
  const shieldGlow4 = interpolate(frame, [scene4Start + 10, scene4Start + 60], [0, 1], { extrapolateRight: "clamp" });
  const shieldRotate = interpolate(frame, [scene4Start + 10, scene4Start + 60], [180, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const trustY4 = interpolate(frame, [scene4Start + 20, scene4Start + 65], [70, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const trust2Y4 = interpolate(frame, [scene4Start + 35, scene4Start + 80], [70, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const b1scale = spring({ frame: frame - (scene4Start + 60), fps, config: { damping: 12, stiffness: 180, mass: 0.6 } });
  const b2scale = spring({ frame: frame - (scene4Start + 80), fps, config: { damping: 12, stiffness: 180, mass: 0.6 } });
  const b1opacity = interpolate(frame, [scene4Start + 60, scene4Start + 80], [0, 1], { extrapolateRight: "clamp" });
  const b2opacity = interpolate(frame, [scene4Start + 80, scene4Start + 100], [0, 1], { extrapolateRight: "clamp" });
  // NEW: shield pulse rings
  const shieldPulse = interpolate(frame, [0, 60, 120], [1, 1.4, 1], { extrapolateRight: "wrap" });

  // ==========================================
  // SCENE 5 — STORIES
  // ==========================================
  const s5opacity = interpolate(frame,
    [scene5Start - 5, scene5Start + 20, scene5Start + scene5Duration - 30, scene5Start + scene5Duration],
    [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const headW5 = interpolate(frame, [scene5Start + 10, scene5Start + 55], [0, 100], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const headOpacity5 = interpolate(frame, [scene5Start + 10, scene5Start + 30], [0, 1], { extrapolateRight: "clamp" });
  const card1x = interpolate(frame, [scene5Start + 25, scene5Start + 75], [-350, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const card1RotY = interpolate(frame, [scene5Start + 25, scene5Start + 75], [-30, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const card1Opacity = interpolate(frame, [scene5Start + 25, scene5Start + 55], [0, 1], { extrapolateRight: "clamp" });
  const card2x = interpolate(frame, [scene5Start + 50, scene5Start + 100], [350, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const card2RotY = interpolate(frame, [scene5Start + 50, scene5Start + 100], [30, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const card2Opacity = interpolate(frame, [scene5Start + 50, scene5Start + 80], [0, 1], { extrapolateRight: "clamp" });
  const bottomY5 = interpolate(frame, [scene5Start + 100, scene5Start + 140], [40, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const bottomOpacity5 = interpolate(frame, [scene5Start + 100, scene5Start + 140], [0, 1], { extrapolateRight: "clamp" });

  // ==========================================
  // SCENE 6 — METRICS DASHBOARD (NEW)
  // ==========================================
  const s6opacity = interpolate(frame,
    [scene6Start - 5, scene6Start + 20, scene6Start + scene6Duration - 30, scene6Start + scene6Duration],
    [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const s6HeadY = interpolate(frame, [scene6Start, scene6Start + 40], [80, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.5)) });
  const s6HeadOpacity = interpolate(frame, [scene6Start, scene6Start + 40], [0, 1], { extrapolateRight: "clamp" });
  // Bar chart bars animate in
  const bar1H = interpolate(frame, [scene6Start + 30, scene6Start + 80], [0, 72], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const bar2H = interpolate(frame, [scene6Start + 45, scene6Start + 95], [0, 55], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const bar3H = interpolate(frame, [scene6Start + 60, scene6Start + 110], [0, 85], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const bar4H = interpolate(frame, [scene6Start + 75, scene6Start + 125], [0, 40], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const bar5H = interpolate(frame, [scene6Start + 90, scene6Start + 140], [0, 93], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  // Stat counters
  const stat1Val = interpolate(frame, [scene6Start + 40, scene6Start + 110], [0, 34], { extrapolateRight: "clamp" });
  const stat2Val = interpolate(frame, [scene6Start + 50, scene6Start + 120], [0, 89], { extrapolateRight: "clamp" });
  const stat3Val = interpolate(frame, [scene6Start + 60, scene6Start + 130], [0, 2.4], { extrapolateRight: "clamp" });
  const stat1Scale = spring({ frame: frame - (scene6Start + 40), fps, config: { damping: 14, stiffness: 160, mass: 0.7 } });
  const stat2Scale = spring({ frame: frame - (scene6Start + 55), fps, config: { damping: 14, stiffness: 160, mass: 0.7 } });
  const stat3Scale = spring({ frame: frame - (scene6Start + 70), fps, config: { damping: 14, stiffness: 160, mass: 0.7 } });

  // ==========================================
  // SCENE 7 — HOW IT WORKS (NEW)
  // ==========================================
  const s7opacity = interpolate(frame,
    [scene7Start - 5, scene7Start + 20, scene7Start + scene7Duration - 30, scene7Start + scene7Duration],
    [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const s7HeadY = interpolate(frame, [scene7Start, scene7Start + 40], [60, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.3)) });
  const s7HeadO = interpolate(frame, [scene7Start, scene7Start + 40], [0, 1], { extrapolateRight: "clamp" });
  const step1S = spring({ frame: frame - (scene7Start + 25), fps, config: { damping: 16, stiffness: 120, mass: 0.9 } });
  const step2S = spring({ frame: frame - (scene7Start + 55), fps, config: { damping: 16, stiffness: 120, mass: 0.9 } });
  const step3S = spring({ frame: frame - (scene7Start + 85), fps, config: { damping: 16, stiffness: 120, mass: 0.9 } });
  const step1O = interpolate(frame, [scene7Start + 25, scene7Start + 50], [0, 1], { extrapolateRight: "clamp" });
  const step2O = interpolate(frame, [scene7Start + 55, scene7Start + 80], [0, 1], { extrapolateRight: "clamp" });
  const step3O = interpolate(frame, [scene7Start + 85, scene7Start + 110], [0, 1], { extrapolateRight: "clamp" });
  // Connector line draw
  const connector1W = interpolate(frame, [scene7Start + 50, scene7Start + 80], [0, 1], { extrapolateRight: "clamp" });
  const connector2W = interpolate(frame, [scene7Start + 80, scene7Start + 110], [0, 1], { extrapolateRight: "clamp" });

  // ==========================================
  // SCENE 8 — INTEGRATIONS (NEW)
  // ==========================================
  const s8opacity = interpolate(frame,
    [scene8Start - 5, scene8Start + 20, scene8Start + scene8Duration - 30, scene8Start + scene8Duration],
    [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const s8HeadY = interpolate(frame, [scene8Start, scene8Start + 40], [60, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.3)) });
  const s8HeadO = interpolate(frame, [scene8Start, scene8Start + 40], [0, 1], { extrapolateRight: "clamp" });
  const centerPulse = interpolate(frame, [0, 45, 90], [1, 1.12, 1], { extrapolateRight: "wrap" });
  // Integration orbit
  const orbitAngle8 = interpolate(frame, [scene8Start, scene8Start + scene8Duration], [0, 120], { extrapolateRight: "clamp" });
  const int1S = spring({ frame: frame - (scene8Start + 20), fps, config: { damping: 18, stiffness: 100, mass: 1 } });
  const int2S = spring({ frame: frame - (scene8Start + 35), fps, config: { damping: 18, stiffness: 100, mass: 1 } });
  const int3S = spring({ frame: frame - (scene8Start + 50), fps, config: { damping: 18, stiffness: 100, mass: 1 } });
  const int4S = spring({ frame: frame - (scene8Start + 65), fps, config: { damping: 18, stiffness: 100, mass: 1 } });
  const int5S = spring({ frame: frame - (scene8Start + 80), fps, config: { damping: 18, stiffness: 100, mass: 1 } });
  const int6S = spring({ frame: frame - (scene8Start + 95), fps, config: { damping: 18, stiffness: 100, mass: 1 } });

  // ==========================================
  // SCENE 9 — CTA (was scene 6)
  // ==========================================
  const s9opacity = interpolate(frame, [scene9Start - 5, scene9Start + 20], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const heartScale9 = spring({ frame: frame - scene9Start, fps, config: { damping: 18, stiffness: 70, mass: 1.3 } });
  const heartbeat = interpolate(frame, [0, 45, 90], [1, 1.08, 1], { extrapolateRight: "wrap" });
  const glowPulse = interpolate(frame, [0, 55, 110], [0.5, 1, 0.5], { extrapolateRight: "wrap" });
  const headline9Y = interpolate(frame, [scene9Start + 10, scene9Start + 50], [60, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.back(1.3)) });
  const headline9Opacity = interpolate(frame, [scene9Start + 10, scene9Start + 50], [0, 1], { extrapolateRight: "clamp" });
  const sub9Y = interpolate(frame, [scene9Start + 30, scene9Start + 65], [40, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const sub9Opacity = interpolate(frame, [scene9Start + 30, scene9Start + 65], [0, 1], { extrapolateRight: "clamp" });
  const cta9Scale = spring({ frame: frame - (scene9Start + 50), fps, config: { damping: 15, stiffness: 140, mass: 0.8 } });
  const cta9Opacity = interpolate(frame, [scene9Start + 50, scene9Start + 75], [0, 1], { extrapolateRight: "clamp" });
  const tag9Opacity = interpolate(frame, [scene9Start + 80, scene9Start + 110], [0, 1], { extrapolateRight: "clamp" });

  // ==========================================
  // TRANSITIONS
  // ==========================================
  const t1flash = interpolate(frame, [scene2Start - 30, scene2Start + 5], [0, 0.3], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const t2sliceP = interpolate(frame, [scene3Start - 25, scene3Start + 5], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
  const t3burstS = interpolate(frame, [scene4Start - 20, scene4Start], [1, 8], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.in(Easing.cubic) });
  const t3burstO = interpolate(frame, [scene4Start - 20, scene4Start], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const t4diagW = interpolate(frame, [scene5Start - 25, scene5Start + 5], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
  const t5flash = interpolate(frame, [scene6Start - 15, scene6Start - 5, scene6Start + 10], [0, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const t6wipe = interpolate(frame, [scene7Start - 20, scene7Start + 5], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
  const t7flash = interpolate(frame, [scene8Start - 10, scene8Start + 10], [0.4, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const t8wipe = interpolate(frame, [scene9Start - 20, scene9Start + 5], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });

  const phoneW = 260;
  const phoneH = 530;

  // SVG arc helper for progress ring
  const describeArc = (cx: number, cy: number, r: number, startAngle: number, endAngle: number) => {
    const toRad = (deg: number) => (deg - 90) * (Math.PI / 180);
    const x1 = cx + r * Math.cos(toRad(startAngle));
    const y1 = cy + r * Math.sin(toRad(startAngle));
    const x2 = cx + r * Math.cos(toRad(endAngle));
    const y2 = cy + r * Math.sin(toRad(endAngle));
    const large = endAngle - startAngle > 180 ? 1 : 0;
    return `M ${x1} ${y1} A ${r} ${r} 0 ${large} 1 ${x2} ${y2}`;
  };

  return (
    <div style={{
      flex: 1, backgroundColor: "#070a12",
      backgroundImage: `
        radial-gradient(ellipse 900px 700px at 20% 30%, rgba(16,185,129,0.13) 0%, transparent 55%),
        radial-gradient(ellipse 700px 600px at 80% 70%, rgba(59,130,246,0.10) 0%, transparent 55%),
        radial-gradient(ellipse 600px 500px at 55% 95%, rgba(99,102,241,0.07) 0%, transparent 50%)
      `,
      position: "relative", overflow: "hidden",
    }}>

      {/* ROTATING BG GRADIENT */}
      <div style={{
        position: "absolute", inset: -200,
        background: `conic-gradient(from ${bgRotate}deg at 50% 50%, rgba(16,185,129,0.03), rgba(59,130,246,0.03), rgba(99,102,241,0.02), transparent 60%)`,
        pointerEvents: "none",
      }} />

      {/* GRAIN */}
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 512 512' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.75' numOctaves='4'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='0.03'/%3E%3C/svg%3E")`,
        mixBlendMode: "overlay", opacity: 0.7,
      }} />

      {/* SCANLINE */}
      <div style={{ position: "absolute", left: 0, right: 0, top: scanline, height: 3, background: "linear-gradient(90deg,transparent,rgba(16,185,129,0.15),transparent)", pointerEvents: "none" }} />

      {/* PARTICLES — extended set */}
      {([
        { top: "18%", left: "12%", size: 9, color: "16,185,129", offset: p1 },
        { top: "62%", right: "18%", size: 13, color: "59,130,246", offset: p2 },
        { top: "33%", right: "10%", size: 6, color: "16,185,129", offset: p3 },
        { bottom: "22%", left: "22%", size: 11, color: "99,102,241", offset: p4 },
        { top: "10%", right: "35%", size: 5, color: "59,130,246", offset: p1 },
        { top: "75%", left: "8%", size: 7, color: "16,185,129", offset: fp1 },
        { top: "45%", left: "45%", size: 4, color: "251,191,36", offset: fp2 },
        { bottom: "10%", right: "12%", size: 8, color: "99,102,241", offset: fp3 },
        { top: "5%", left: "55%", size: 6, color: "16,185,129", offset: fp2 },
      ] as Array<{ top?: string; bottom?: string; left?: string; right?: string; size: number; color: string; offset: number }>).map((p, i) => (
        <div key={i} style={{
          position: "absolute", top: p.top, left: p.left, right: p.right, bottom: p.bottom,
          width: p.size, height: p.size, borderRadius: "50%",
          backgroundColor: `rgba(${p.color},0.5)`,
          transform: `translateY(${p.offset}px)`,
          boxShadow: `0 0 ${p.size * 3}px rgba(${p.color},0.7)`,
          opacity: 0.85 * ambientPulse,
        }} />
      ))}

      {/* AMBIENT */}
      <div style={{ position: "absolute", inset: 0, background: `linear-gradient(135deg,rgba(16,185,129,${0.07 * ambientPulse}) 0%,transparent 40%,rgba(59,130,246,${0.05 * ambientPulse}) 100%)`, pointerEvents: "none" }} />

      {/* ══ SCENE 1 ══ */}
      {frame < scene2Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", opacity: s1out, perspective: "1200px" }}>
          {/* DNA helix lines */}
          <svg style={{ position: "absolute", inset: 0, width: "100%", height: "100%", opacity: helixOpacity }} viewBox="0 0 1920 1080">
            {Array.from({ length: 12 }).map((_, i) => {
              const y = 100 + i * 80;
              const amp = 60;
              const freq = 0.012;
              const shift = helixShift * 6;
              const points1 = Array.from({ length: 100 }, (__, j) => `${j * 20},${y + amp * Math.sin(j * freq * 20 + shift)}`).join(" ");
              const points2 = Array.from({ length: 100 }, (__, j) => `${j * 20},${y + amp * Math.sin(j * freq * 20 + shift + Math.PI)}`).join(" ");
              return (
                <g key={i}>
                  <polyline points={points1} fill="none" stroke="rgba(16,185,129,0.15)" strokeWidth="1.5" />
                  <polyline points={points2} fill="none" stroke="rgba(59,130,246,0.12)" strokeWidth="1.5" />
                </g>
              );
            })}
          </svg>

          {[{ size: 500, color: "16,185,129", speed: 1, dot: 12 }, { size: 350, color: "59,130,246", speed: -1.3, dot: 10 }, { size: 650, color: "99,102,241", speed: 0.6, dot: 7 }].map((r, i) => (
            <div key={i} style={{ position: "absolute", width: r.size, height: r.size, borderRadius: "50%", border: `1px solid rgba(${r.color},0.15)`, transform: `rotate(${orbitAngle * r.speed}deg)`, opacity: logoEntryProgress }}>
              <div style={{ position: "absolute", top: -r.dot / 2, left: "50%", width: r.dot, height: r.dot, borderRadius: "50%", backgroundColor: `rgba(${r.color},0.8)`, boxShadow: `0 0 20px rgba(${r.color},1)`, transform: "translateX(-50%)" }} />
            </div>
          ))}
          <div style={{ transform: `translateY(${logoY1}px) scale(${logoScale1}) rotateX(${logoPerspX}deg)`, opacity: logoEntryProgress, position: "relative", marginBottom: 35 }}>
            <div style={{ fontSize: 148, fontFamily: "'Epilogue','system-ui',sans-serif", fontWeight: 800, background: "linear-gradient(135deg,#10b981 0%,#34d399 40%,#3b82f6 100%)", WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent", backgroundClip: "text", letterSpacing: "-0.03em", filter: `drop-shadow(0 0 ${60 * logoGlow1}px rgba(16,185,129,${0.9 * logoGlow1}))` }}>Adaptly</div>
            <div style={{ position: "absolute", bottom: -8, left: 0, height: 5, width: `${underlineW}%`, background: "linear-gradient(90deg,#10b981,#3b82f6)", borderRadius: 3, boxShadow: "0 0 25px rgba(16,185,129,0.8)" }} />
          </div>
          <div style={{ fontSize: 50, fontFamily: "'DM Sans',sans-serif", fontWeight: 600, color: "#10b981", transform: `translateX(${tagX}px)`, opacity: tagOpacity, textAlign: "center", marginBottom: 20, textShadow: "0 0 40px rgba(16,185,129,0.4)" }}>Your guide to recovery and beyond</div>
          <div style={{ fontSize: 32, fontFamily: "'DM Sans',sans-serif", fontWeight: 400, color: "rgba(255,255,255,0.7)", transform: `translateX(${subX}px)`, opacity: subOpacity, textAlign: "center", lineHeight: 1.5 }}>
            Post-discharge recovery guidance + tracking<br />
            <span style={{ color: "rgba(255,255,255,0.45)", fontSize: 26 }}>for rehab and care teams</span>
          </div>
        </div>
      )}

      {/* T1 */}
      {frame >= scene2Start - 30 && frame < scene2Start + 5 && (
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(135deg,#10b981,#3b82f6)", opacity: t1flash }} />
      )}

      {/* ══ SCENE 2 ══ */}
      {frame >= scene2Start && frame < scene3Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", opacity: s2opacity, padding: "80px 100px", gap: 45 }}>
          {/* Ripple rings */}
          <div style={{ position: "relative", display: "flex", justifyContent: "center", alignItems: "center" }}>
            <div style={{ position: "absolute", width: 200, height: 200, borderRadius: "50%", border: "2px solid rgba(251,191,36,0.2)", transform: `scale(${1 + ripple1 * 1.5})`, opacity: (1 - ripple1) * 0.6 }} />
            <div style={{ position: "absolute", width: 200, height: 200, borderRadius: "50%", border: "2px solid rgba(239,68,68,0.15)", transform: `scale(${1 + ripple2 * 2})`, opacity: (1 - ripple2) * 0.5 }} />
            <div style={{ transform: `scale(${warnScale}) rotate(${warnRotate}deg)`, opacity: Math.min(warnScale, 1) }}>
              <svg width="95" height="95" viewBox="0 0 90 90" style={{ filter: "drop-shadow(0 0 30px rgba(251,191,36,0.8))" }}>
                <circle cx="45" cy="45" r="40" fill="none" stroke="#fbbf24" strokeWidth="4" />
                <path d="M 45 20 L 45 50" stroke="#fbbf24" strokeWidth="6" strokeLinecap="round" />
                <circle cx="45" cy="65" r="5" fill="#fbbf24" />
              </svg>
            </div>
          </div>
          <div style={{ fontSize: 60, fontFamily: "'DM Sans',sans-serif", fontWeight: 600, color: "white", textAlign: "center", lineHeight: 1.35, transform: `translateX(${probX}px) translateY(${probY2}px) skewX(${probSkew}deg)`, maxWidth: 1050 }}>
            After discharge, patients face a <span style={{ color: "#ef4444", fontWeight: 700 }}>critical gap</span>
          </div>
          <div style={{ position: "relative", opacity: statReveal, transform: `scale(${statZoom * statPulse})` }}>
            <div style={{ position: "absolute", inset: -30, borderRadius: "50%", border: "2px solid rgba(251,191,36,0.3)", transform: `scale(${statPulse})` }} />
            <div style={{ position: "absolute", inset: -15, borderRadius: "50%", border: "2px solid rgba(251,191,36,0.2)" }} />
            <div style={{ fontSize: 80, fontFamily: "'Epilogue',sans-serif", fontWeight: 800, color: "#fbbf24", textShadow: "0 0 60px rgba(251,191,36,0.7)" }}>65%</div>
          </div>
          <div style={{ transform: `translateX(${sub1X}px)`, opacity: sub1Reveal, fontSize: 42, fontFamily: "'DM Sans',sans-serif", fontWeight: 500, color: "rgba(255,255,255,0.88)", textAlign: "center", maxWidth: 900 }}>
            of patients feel <span style={{ fontWeight: 700, color: "#fff" }}>confused and unsupported</span>
          </div>
          <div style={{ transform: `translateX(${sub2X}px)`, opacity: sub2Reveal, fontSize: 28, fontFamily: "'DM Sans',sans-serif", fontWeight: 400, color: "rgba(255,255,255,0.55)", fontStyle: "italic", textAlign: "center" }}>
            Leading to preventable readmissions and slower recovery
          </div>
        </div>
      )}

      {/* T2 */}
      {frame >= scene3Start - 25 && frame < scene3Start + 5 && (
        <>
          <div style={{ position: "absolute", top: 0, bottom: 0, left: 0, width: `${t2sliceP * 50}%`, background: "linear-gradient(180deg,rgba(16,185,129,0.4),rgba(59,130,246,0.3))", opacity: 0.6 }} />
          <div style={{ position: "absolute", top: 0, bottom: 0, right: 0, width: `${t2sliceP * 50}%`, background: "linear-gradient(180deg,rgba(59,130,246,0.3),rgba(16,185,129,0.4))", opacity: 0.6 }} />
        </>
      )}

      {/* ══ SCENE 3: FEATURES + iPHONE (fixed screen) ══ */}
      {frame >= scene3Start && frame < scene4Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "row", alignItems: "center", opacity: s3opacity, padding: "50px 110px", gap: 90 }}>

          {/* LEFT TEXT */}
          <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 30 }}>
            <div style={{ transform: `translateY(${s3LogoY}px)`, opacity: s3LogoOpacity }}>
              <div style={{ fontSize: 68, fontFamily: "'Epilogue',sans-serif", fontWeight: 800, background: "linear-gradient(135deg,#10b981,#3b82f6)", WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent", backgroundClip: "text", letterSpacing: "-0.02em", filter: "drop-shadow(0 0 30px rgba(16,185,129,0.6))" }}>Adaptly</div>
            </div>
            <div style={{ fontSize: 46, fontFamily: "'Epilogue',sans-serif", fontWeight: 700, color: "#10b981", transform: `translateY(${headY3}px)`, opacity: headOpacity3, textShadow: "0 0 35px rgba(16,185,129,0.5)", lineHeight: 1.25 }}>
              Guides them<br />home, safely
            </div>
            {[
              { icon: "✓", label: "AI-Powered Recovery Plans", color: "16,185,129", ox: f1x, oo: f1o },
              { icon: "⟳", label: "Real-Time Team Coordination", color: "59,130,246", ox: f2x, oo: f2o },
              { icon: "🔒", label: "Enterprise-Grade Security", color: "99,102,241", ox: f3x, oo: f3o },
            ].map((f, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 16, transform: `translateX(${f.ox}px)`, opacity: f.oo }}>
                <div style={{ width: 44, height: 44, borderRadius: 12, backgroundColor: `rgba(${f.color},0.15)`, border: `2px solid rgba(${f.color},0.4)`, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 20, flexShrink: 0, boxShadow: `0 0 20px rgba(${f.color},0.2)` }}>{f.icon}</div>
                <div style={{ fontSize: 28, fontFamily: "'DM Sans',sans-serif", fontWeight: 600, color: "rgba(255,255,255,0.9)" }}>{f.label}</div>
              </div>
            ))}
          </div>

          {/* RIGHT: iPHONE MOCKUP — fixed screen, animated progress ring + notification */}
          <div style={{ flexShrink: 0, transform: `translateY(${phoneY + phoneSway}px) rotate(${phoneRotate}deg) scale(${phoneScale3})`, opacity: phoneOpacity }}>
            <div style={{
              width: phoneW, height: phoneH, borderRadius: 50,
              background: "linear-gradient(145deg,#2a2a2a 0%,#1a1a1a 40%,#111 100%)",
              padding: 4,
              boxShadow: `0 0 0 1px rgba(255,255,255,0.12), 0 30px 80px rgba(0,0,0,0.8), 0 0 ${60 * phoneGlow}px rgba(16,185,129,${0.4 * phoneGlow}), inset 0 1px 0 rgba(255,255,255,0.15)`,
              position: "relative",
            }}>
              {/* Side buttons */}
              <div style={{ position: "absolute", left: -3, top: 100, width: 3, height: 35, backgroundColor: "#333", borderRadius: "2px 0 0 2px" }} />
              <div style={{ position: "absolute", left: -3, top: 145, width: 3, height: 60, backgroundColor: "#333", borderRadius: "2px 0 0 2px" }} />
              <div style={{ position: "absolute", left: -3, top: 215, width: 3, height: 60, backgroundColor: "#333", borderRadius: "2px 0 0 2px" }} />
              <div style={{ position: "absolute", right: -3, top: 140, width: 3, height: 80, backgroundColor: "#333", borderRadius: "0 2px 2px 0" }} />

              {/* Screen */}
              <div style={{ width: "100%", height: "100%", borderRadius: 47, overflow: "hidden", backgroundColor: "#0d1520", position: "relative" }}>
                {/* Dynamic Island */}
                <div style={{ position: "absolute", top: 12, left: "50%", transform: "translateX(-50%)", width: 100, height: 28, borderRadius: 20, backgroundColor: "#000", zIndex: 10 }} />
                {/* Status bar */}
                <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 50, display: "flex", justifyContent: "space-between", alignItems: "flex-end", padding: "0 22px 6px", zIndex: 5 }}>
                  <div style={{ fontSize: 11, color: "white", fontWeight: 600, fontFamily: "system-ui" }}>12:28</div>
                  <div style={{ fontSize: 9, color: "white", fontFamily: "system-ui" }}>●●● WiFi</div>
                </div>

                {/* FIXED APP CONTENT: Dashboard view */}
                <div style={{ position: "absolute", top: 55, left: 0, right: 0, bottom: 0, padding: "10px 14px" }}>
                  {/* Header */}
                  <div style={{ fontSize: 14, fontWeight: 700, color: "white", fontFamily: "system-ui", marginBottom: 3 }}>Good morning 👋</div>
                  <div style={{ fontSize: 10, color: "rgba(255,255,255,0.5)", fontFamily: "system-ui", marginBottom: 14 }}>Day 4 of recovery</div>

                  {/* Progress ring card */}
                  <div style={{ backgroundColor: "rgba(16,185,129,0.1)", borderRadius: 14, padding: "12px", border: "1px solid rgba(16,185,129,0.25)", marginBottom: 10, display: "flex", alignItems: "center", gap: 12 }}>
                    <svg width="62" height="62" viewBox="0 0 62 62">
                      <circle cx="31" cy="31" r="25" fill="none" stroke="rgba(16,185,129,0.15)" strokeWidth="5" />
                      <path d={describeArc(31, 31, 25, 0, Math.max(1, progressArc))} fill="none" stroke="#10b981" strokeWidth="5" strokeLinecap="round" />
                      <text x="31" y="36" textAnchor="middle" fill="#10b981" fontSize="12" fontWeight="700" fontFamily="system-ui">{Math.round((progressArc / 270) * 75)}%</text>
                    </svg>
                    <div>
                      <div style={{ fontSize: 12, fontWeight: 700, color: "white", fontFamily: "system-ui" }}>Recovery Progress</div>
                      <div style={{ fontSize: 9, color: "rgba(255,255,255,0.5)", fontFamily: "system-ui", marginTop: 2 }}>On track for full recovery</div>
                      <div style={{ marginTop: 6, height: 4, borderRadius: 2, backgroundColor: "rgba(255,255,255,0.1)", overflow: "hidden" }}>
                        <div style={{ height: "100%", width: `${(progressArc / 270) * 75}%`, background: "linear-gradient(90deg,#10b981,#34d399)", borderRadius: 2 }} />
                      </div>
                    </div>
                  </div>

                  {/* Today's tasks */}
                  <div style={{ fontSize: 10, fontWeight: 700, color: "rgba(255,255,255,0.6)", fontFamily: "system-ui", marginBottom: 6, letterSpacing: "0.08em", textTransform: "uppercase" }}>Today's Plan</div>
                  {[
                    { task: "Morning exercises", done: true, time: "8:00 AM" },
                    { task: "Medication reminder", done: true, time: "10:00 AM" },
                    { task: "PT Check-in call", done: false, time: "2:00 PM" },
                  ].map((t, i) => (
                    <div key={i} style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8, padding: "7px 10px", borderRadius: 10, backgroundColor: t.done ? "rgba(16,185,129,0.08)" : "rgba(255,255,255,0.04)", border: `1px solid ${t.done ? "rgba(16,185,129,0.2)" : "rgba(255,255,255,0.08)"}` }}>
                      <div style={{ width: 16, height: 16, borderRadius: "50%", backgroundColor: t.done ? "#10b981" : "transparent", border: `2px solid ${t.done ? "#10b981" : "rgba(255,255,255,0.2)"}`, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                        {t.done && <div style={{ width: 6, height: 6, borderRadius: "50%", backgroundColor: "white" }} />}
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: 10, color: t.done ? "rgba(255,255,255,0.5)" : "white", fontFamily: "system-ui", fontWeight: 600, textDecoration: t.done ? "line-through" : "none" }}>{t.task}</div>
                        <div style={{ fontSize: 8, color: "rgba(255,255,255,0.35)", fontFamily: "system-ui" }}>{t.time}</div>
                      </div>
                    </div>
                  ))}
                </div>

                {/* Notification pop-in */}
                <div style={{ position: "absolute", top: 12, left: 8, right: 8, backgroundColor: "rgba(20,25,40,0.95)", borderRadius: 16, padding: "10px 12px", border: "1px solid rgba(59,130,246,0.4)", transform: `scale(${notifScale})`, opacity: notifOpacity, boxShadow: "0 8px 30px rgba(0,0,0,0.5)", zIndex: 20, backdropFilter: "blur(10px)" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <div style={{ width: 28, height: 28, borderRadius: 8, background: "linear-gradient(135deg,#1a9ba1,#0ea5e9)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14, flexShrink: 0 }}>💬</div>
                    <div>
                      <div style={{ fontSize: 10, fontWeight: 700, color: "white", fontFamily: "system-ui" }}>Dr. Martinez</div>
                      <div style={{ fontSize: 9, color: "rgba(255,255,255,0.6)", fontFamily: "system-ui" }}>Your PT notes look great today!</div>
                    </div>
                  </div>
                </div>

                {/* Screen glare */}
                <div style={{ position: "absolute", inset: 0, background: "linear-gradient(135deg,rgba(255,255,255,0.04) 0%,transparent 50%)", pointerEvents: "none", borderRadius: 47 }} />
                <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 120, background: `radial-gradient(ellipse at 50% 100%,rgba(16,185,129,${0.15 * phoneGlow}),transparent)`, pointerEvents: "none" }} />
              </div>
            </div>
            {/* Halo */}
            <div style={{ position: "absolute", bottom: -30, left: "50%", transform: "translateX(-50%)", width: 200, height: 40, background: `radial-gradient(ellipse,rgba(16,185,129,${0.35 * phoneGlow}),transparent)`, filter: "blur(15px)" }} />
          </div>
        </div>
      )}

      {/* T3: zoom burst */}
      {frame >= scene4Start - 20 && frame < scene4Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", justifyContent: "center", alignItems: "center", pointerEvents: "none" }}>
          <div style={{ width: 100, height: 100, borderRadius: "50%", background: "radial-gradient(circle,rgba(59,130,246,0.8),rgba(16,185,129,0.4))", transform: `scale(${t3burstS})`, opacity: Math.max(0, t3burstO * (1 - (t3burstS - 1) / 7)) }} />
        </div>
      )}

      {/* ══ SCENE 4: TRUST ══ */}
      {frame >= scene4Start && frame < scene5Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", opacity: s4opacity, padding: 100, gap: 50 }}>
          <div style={{ position: "relative", transform: `scale(${shieldS}) rotate(${shieldRotate}deg)`, opacity: Math.min(shieldS, 1) }}>
            {/* Pulse rings */}
            <div style={{ position: "absolute", inset: -20, borderRadius: "50%", border: "2px solid rgba(59,130,246,0.2)", transform: `scale(${shieldPulse})`, opacity: shieldGlow4 }} />
            <div style={{ position: "absolute", inset: -40, borderRadius: "50%", border: "1px solid rgba(59,130,246,0.1)", transform: `scale(${1 + (shieldPulse - 1) * 1.5})`, opacity: shieldGlow4 * 0.5 }} />
            <svg width="115" height="115" viewBox="0 0 110 110" style={{ filter: `drop-shadow(0 0 ${40 * shieldGlow4}px rgba(59,130,246,${shieldGlow4}))` }}>
              <path d="M 55 10 L 20 25 L 20 55 C 20 75 55 90 55 90 C 55 90 90 75 90 55 L 90 25 Z" fill="none" stroke="#3b82f6" strokeWidth="4" />
              <path d="M 40 52 L 50 62 L 70 40" stroke="#3b82f6" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
            </svg>
          </div>
          <div style={{ fontSize: 66, fontFamily: "'Epilogue',sans-serif", fontWeight: 700, color: "white", textAlign: "center", lineHeight: 1.3, transform: `translateY(${trustY4}px)`, maxWidth: 1000 }}>Trusted by healthcare teams</div>
          <div style={{ fontSize: 74, fontFamily: "'Epilogue',sans-serif", fontWeight: 800, color: "#3b82f6", textAlign: "center", transform: `translateY(${trust2Y4}px)`, textShadow: "0 0 50px rgba(59,130,246,0.6)" }}>to reduce readmissions</div>
          <div style={{ display: "flex", gap: 55, marginTop: 15 }}>
            {[
              { emoji: "🏥", label: "Hospital\nApproved", color: "16,185,129", s: b1scale, o: b1opacity },
              { emoji: "🔒", label: "HIPAA\nCompliant", color: "99,102,241", s: b2scale, o: b2opacity },
            ].map((b, i) => (
              <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 14, transform: `scale(${b.s})`, opacity: b.o }}>
                <div style={{ width: 90, height: 90, borderRadius: "50%", backgroundColor: `rgba(${b.color},0.15)`, border: `3px solid rgba(${b.color},0.45)`, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 42, boxShadow: `0 0 30px rgba(${b.color},0.3)` }}>{b.emoji}</div>
                <div style={{ fontSize: 25, fontFamily: "'DM Sans',sans-serif", fontWeight: 600, color: "rgba(255,255,255,0.85)", textAlign: "center", whiteSpace: "pre-line" }}>{b.label}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* T4: diagonal wipe */}
      {frame >= scene5Start - 25 && frame < scene5Start + 5 && (
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(135deg,rgba(16,185,129,0.35) 0%,rgba(59,130,246,0.25) 100%)", clipPath: `polygon(0 0,${t4diagW * 100}% 0,${t4diagW * 100 - 30}% 100%,0 100%)`, opacity: 0.8 }} />
      )}

      {/* ══ SCENE 5: STORIES ══ */}
      {frame >= scene5Start && frame < scene6Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", opacity: s5opacity, padding: "70px 90px", gap: 45 }}>
          <div style={{ overflow: "hidden", opacity: headOpacity5 }}>
            <div style={{ fontSize: 64, fontFamily: "'Epilogue',sans-serif", fontWeight: 700, color: "white", textAlign: "center", clipPath: `inset(0 ${100 - headW5}% 0 0)` }}>Real impact on real people</div>
          </div>
          <div style={{ display: "flex", gap: 40, width: "100%", maxWidth: 1250, justifyContent: "center" }}>
            <div style={{ flex: 1, backgroundColor: "rgba(16,185,129,0.09)", padding: "32px 38px", borderRadius: 22, border: "2px solid rgba(16,185,129,0.32)", transform: `translateX(${card1x}px) rotateY(${card1RotY}deg)`, opacity: card1Opacity, boxShadow: "0 12px 50px rgba(16,185,129,0.22)" }}>
              <div style={{ width: 68, height: 68, borderRadius: "50%", backgroundColor: "rgba(16,185,129,0.2)", border: "2px solid rgba(16,185,129,0.45)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 36, marginBottom: 22 }}>❤️</div>
              <div style={{ fontSize: 21, fontFamily: "'DM Sans',sans-serif", fontWeight: 600, color: "#10b981", marginBottom: 14, letterSpacing: "0.06em", textTransform: "uppercase" }}>Patient Perspective</div>
              <div style={{ fontSize: 28, fontFamily: "'DM Sans',sans-serif", fontWeight: 500, color: "rgba(255,255,255,0.92)", lineHeight: 1.55, fontStyle: "italic" }}>"Finally felt supported at home. Clear milestones made recovery less overwhelming."</div>
              <div style={{ fontSize: 20, fontFamily: "'DM Sans',sans-serif", color: "rgba(255,255,255,0.55)", marginTop: 18 }}>— Sarah, recovering from surgery</div>
            </div>
            <div style={{ flex: 1, backgroundColor: "rgba(59,130,246,0.09)", padding: "32px 38px", borderRadius: 22, border: "2px solid rgba(59,130,246,0.32)", transform: `translateX(${card2x}px) rotateY(${card2RotY}deg)`, opacity: card2Opacity, boxShadow: "0 12px 50px rgba(59,130,246,0.22)" }}>
              <div style={{ width: 68, height: 68, borderRadius: "50%", backgroundColor: "rgba(59,130,246,0.2)", border: "2px solid rgba(59,130,246,0.45)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 36, marginBottom: 22 }}>👨‍⚕️</div>
              <div style={{ fontSize: 21, fontFamily: "'DM Sans',sans-serif", fontWeight: 600, color: "#3b82f6", marginBottom: 14, letterSpacing: "0.06em", textTransform: "uppercase" }}>Care Team Perspective</div>
              <div style={{ fontSize: 28, fontFamily: "'DM Sans',sans-serif", fontWeight: 500, color: "rgba(255,255,255,0.92)", lineHeight: 1.55, fontStyle: "italic" }}>"Real-time updates keep our team aligned. We catch issues before they become readmissions."</div>
              <div style={{ fontSize: 20, fontFamily: "'DM Sans',sans-serif", color: "rgba(255,255,255,0.55)", marginTop: 18 }}>— Dr. Martinez, Physical Medicine</div>
            </div>
          </div>
          <div style={{ fontSize: 32, fontFamily: "'DM Sans',sans-serif", fontWeight: 500, color: "rgba(255,255,255,0.65)", textAlign: "center", transform: `translateY(${bottomY5}px)`, opacity: bottomOpacity5 }}>Better coordination. Better outcomes.</div>
        </div>
      )}

      {/* T5: white flash */}
      <div style={{ position: "absolute", inset: 0, backgroundColor: "white", opacity: t5flash, pointerEvents: "none" }} />

      {/* ══ SCENE 6: METRICS DASHBOARD (NEW) ══ */}
      {frame >= scene6Start && frame < scene7Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", opacity: s6opacity, padding: "60px 100px", gap: 50 }}>
          <div style={{ transform: `translateY(${s6HeadY}px)`, opacity: s6HeadOpacity }}>
            <div style={{ fontSize: 64, fontFamily: "'Epilogue',sans-serif", fontWeight: 700, color: "white", textAlign: "center" }}>The results speak <span style={{ color: "#10b981" }}>for themselves</span></div>
          </div>

          {/* Stat cards */}
          <div style={{ display: "flex", gap: 40, width: "100%", maxWidth: 1100, justifyContent: "center" }}>
            {[
              { value: stat1Val, scale: stat1Scale, suffix: "%", label: "Reduction in Readmissions", color: "16,185,129", decimals: 0 },
              { value: stat2Val, scale: stat2Scale, suffix: "%", label: "Patient Satisfaction Score", color: "59,130,246", decimals: 0 },
              { value: stat3Val, scale: stat3Scale, suffix: "x", label: "Faster Care Coordination", color: "99,102,241", decimals: 1 },
            ].map((s, i) => (
              <div key={i} style={{ flex: 1, backgroundColor: `rgba(${s.color},0.08)`, border: `2px solid rgba(${s.color},0.25)`, borderRadius: 24, padding: "36px 24px", display: "flex", flexDirection: "column", alignItems: "center", gap: 12, transform: `scale(${s.scale})`, boxShadow: `0 12px 50px rgba(${s.color},0.15)` }}>
                <div style={{ fontSize: 72, fontFamily: "'Epilogue',sans-serif", fontWeight: 800, color: `rgba(${s.color},1)`, textShadow: `0 0 50px rgba(${s.color},0.6)` }}>
                  {s.decimals === 1 ? s.value.toFixed(1) : Math.round(s.value)}{s.suffix}
                </div>
                <div style={{ fontSize: 22, fontFamily: "'DM Sans',sans-serif", fontWeight: 500, color: "rgba(255,255,255,0.75)", textAlign: "center" }}>{s.label}</div>
              </div>
            ))}
          </div>

          {/* Mini bar chart */}
          <div style={{ display: "flex", alignItems: "flex-end", gap: 14, height: 120, padding: "0 20px" }}>
            {[
              { h: bar1H, color: "16,185,129", label: "Jan" },
              { h: bar2H, color: "59,130,246", label: "Feb" },
              { h: bar3H, color: "16,185,129", label: "Mar" },
              { h: bar4H, color: "59,130,246", label: "Apr" },
              { h: bar5H, color: "16,185,129", label: "May" },
            ].map((b, i) => (
              <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
                <div style={{ width: 48, height: `${b.h}px`, backgroundColor: `rgba(${b.color},0.7)`, borderRadius: "6px 6px 0 0", boxShadow: `0 -4px 20px rgba(${b.color},0.4)`, border: `1px solid rgba(${b.color},0.5)` }} />
                <div style={{ fontSize: 18, fontFamily: "'DM Sans',sans-serif", color: "rgba(255,255,255,0.5)" }}>{b.label}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* T6: horizontal wipe */}
      {frame >= scene7Start - 20 && frame < scene7Start + 5 && (
        <div style={{ position: "absolute", top: 0, bottom: 0, left: 0, width: `${t6wipe * 100}%`, background: "linear-gradient(90deg,rgba(16,185,129,0.3),rgba(59,130,246,0.2))", opacity: 0.7 }} />
      )}

      {/* ══ SCENE 7: HOW IT WORKS (NEW) ══ */}
      {frame >= scene7Start && frame < scene8Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", opacity: s7opacity, padding: "60px 120px", gap: 60 }}>
          <div style={{ transform: `translateY(${s7HeadY}px)`, opacity: s7HeadO }}>
            <div style={{ fontSize: 62, fontFamily: "'Epilogue',sans-serif", fontWeight: 700, color: "white", textAlign: "center" }}>How <span style={{ color: "#10b981" }}>Adaptly</span> works</div>
          </div>

          {/* Steps with connector lines */}
          <div style={{ display: "flex", alignItems: "center", gap: 0, width: "100%", maxWidth: 1200 }}>
            {/* Step 1 */}
            <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 18, transform: `scale(${step1S})`, opacity: step1O }}>
              <div style={{ width: 100, height: 100, borderRadius: "50%", background: "linear-gradient(135deg,rgba(16,185,129,0.25),rgba(16,185,129,0.05))", border: "3px solid rgba(16,185,129,0.6)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 44, boxShadow: "0 0 40px rgba(16,185,129,0.3)" }}>🏥</div>
              <div style={{ fontSize: 28, fontFamily: "'DM Sans',sans-serif", fontWeight: 700, color: "#10b981", textAlign: "center" }}>Hospital Discharge</div>
              <div style={{ fontSize: 20, fontFamily: "'DM Sans',sans-serif", color: "rgba(255,255,255,0.6)", textAlign: "center", maxWidth: 280, lineHeight: 1.5 }}>Care team creates a personalized recovery plan</div>
            </div>

            {/* Connector 1 */}
            <div style={{ flexShrink: 0, width: 100, display: "flex", alignItems: "center", justifyContent: "center", marginTop: -40 }}>
              <div style={{ height: 3, width: `${connector1W * 100}%`, background: "linear-gradient(90deg,#10b981,#3b82f6)", borderRadius: 2, boxShadow: "0 0 15px rgba(16,185,129,0.5)", position: "relative" }}>
                <div style={{ position: "absolute", right: -5, top: "50%", transform: "translateY(-50%)", width: 10, height: 10, borderRight: "3px solid #3b82f6", borderTop: "3px solid #3b82f6", transform: "translateY(-50%) rotate(45deg)", opacity: connector1W }} />
              </div>
            </div>

            {/* Step 2 */}
            <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 18, transform: `scale(${step2S})`, opacity: step2O }}>
              <div style={{ width: 100, height: 100, borderRadius: "50%", background: "linear-gradient(135deg,rgba(59,130,246,0.25),rgba(59,130,246,0.05))", border: "3px solid rgba(59,130,246,0.6)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 44, boxShadow: "0 0 40px rgba(59,130,246,0.3)" }}>📱</div>
              <div style={{ fontSize: 28, fontFamily: "'DM Sans',sans-serif", fontWeight: 700, color: "#3b82f6", textAlign: "center" }}>Patient Follows Along</div>
              <div style={{ fontSize: 20, fontFamily: "'DM Sans',sans-serif", color: "rgba(255,255,255,0.6)", textAlign: "center", maxWidth: 280, lineHeight: 1.5 }}>AI-guided tasks, reminders, and milestone tracking</div>
            </div>

            {/* Connector 2 */}
            <div style={{ flexShrink: 0, width: 100, display: "flex", alignItems: "center", justifyContent: "center", marginTop: -40 }}>
              <div style={{ height: 3, width: `${connector2W * 100}%`, background: "linear-gradient(90deg,#3b82f6,#10b981)", borderRadius: 2, boxShadow: "0 0 15px rgba(59,130,246,0.5)" }} />
            </div>

            {/* Step 3 */}
            <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 18, transform: `scale(${step3S})`, opacity: step3O }}>
              <div style={{ width: 100, height: 100, borderRadius: "50%", background: "linear-gradient(135deg,rgba(16,185,129,0.25),rgba(99,102,241,0.05))", border: "3px solid rgba(16,185,129,0.6)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 44, boxShadow: "0 0 40px rgba(16,185,129,0.3)" }}>✅</div>
              <div style={{ fontSize: 28, fontFamily: "'DM Sans',sans-serif", fontWeight: 700, color: "#10b981", textAlign: "center" }}>Team Stays Informed</div>
              <div style={{ fontSize: 20, fontFamily: "'DM Sans',sans-serif", color: "rgba(255,255,255,0.6)", textAlign: "center", maxWidth: 280, lineHeight: 1.5 }}>Real-time alerts and dashboard updates for the whole team</div>
            </div>
          </div>
        </div>
      )}

      {/* T7: flash */}
      {frame >= scene8Start - 10 && frame < scene8Start + 10 && (
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(135deg,rgba(99,102,241,0.5),rgba(16,185,129,0.4))", opacity: t7flash }} />
      )}

      {/* ══ SCENE 8: INTEGRATIONS (NEW) ══ */}
      {frame >= scene8Start && frame < scene9Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", opacity: s8opacity, gap: 50 }}>
          <div style={{ transform: `translateY(${s8HeadY}px)`, opacity: s8HeadO }}>
            <div style={{ fontSize: 62, fontFamily: "'Epilogue',sans-serif", fontWeight: 700, color: "white", textAlign: "center" }}>Plugs into your <span style={{ color: "#3b82f6" }}>existing workflow</span></div>
            <div style={{ fontSize: 28, fontFamily: "'DM Sans',sans-serif", color: "rgba(255,255,255,0.55)", textAlign: "center", marginTop: 10 }}>Native integrations with the tools you already use</div>
          </div>

          {/* Hub and spoke layout */}
          <div style={{ position: "relative", width: 580, height: 380 }}>
            {/* Center hub */}
            <div style={{ position: "absolute", top: "50%", left: "50%", transform: `translate(-50%,-50%) scale(${centerPulse})`, zIndex: 10 }}>
              <div style={{ width: 100, height: 100, borderRadius: "50%", background: "linear-gradient(135deg,#10b981,#3b82f6)", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: `0 0 60px rgba(16,185,129,${glowPulse * 0.5})`, border: "3px solid rgba(255,255,255,0.15)" }}>
                <div style={{ fontSize: 36, fontFamily: "'Epilogue',sans-serif", fontWeight: 800, color: "white" }}>A</div>
              </div>
            </div>

            {/* Spokes + integration nodes */}
            {[
              { label: "Epic EHR", emoji: "🏛️", angle: 0, color: "16,185,129", s: int1S },
              { label: "Cerner", emoji: "📋", angle: 60, color: "59,130,246", s: int2S },
              { label: "MyChart", emoji: "📊", angle: 120, color: "99,102,241", s: int3S },
              { label: "Slack", emoji: "💬", angle: 180, color: "16,185,129", s: int4S },
              { label: "Teams", emoji: "🤝", angle: 240, color: "59,130,246", s: int5S },
              { label: "FHIR API", emoji: "🔌", angle: 300, color: "99,102,241", s: int6S },
            ].map((item, i) => {
              const rad = ((item.angle + orbitAngle8) * Math.PI) / 180;
              const r = 165;
              const x = 290 + r * Math.cos(rad);
              const y = 190 + r * Math.sin(rad);
              return (
                <div key={i} style={{ position: "absolute", transform: `translate(-50%,-50%) scale(${item.s})`, left: x, top: y, zIndex: 5 }}>
                  {/* Line to center */}
                  <svg style={{ position: "absolute", top: 0, left: 0, overflow: "visible", pointerEvents: "none" }} width="1" height="1">
                    <line
                      x1={0} y1={0}
                      x2={290 - x} y2={190 - y}
                      stroke={`rgba(${item.color},0.25)`} strokeWidth="1.5" strokeDasharray="4 4"
                    />
                  </svg>
                  <div style={{ width: 72, height: 72, borderRadius: 18, backgroundColor: `rgba(${item.color},0.12)`, border: `2px solid rgba(${item.color},0.4)`, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 4, boxShadow: `0 4px 24px rgba(${item.color},0.2)` }}>
                    <div style={{ fontSize: 26 }}>{item.emoji}</div>
                    <div style={{ fontSize: 9, fontFamily: "'DM Sans',sans-serif", color: "rgba(255,255,255,0.7)", fontWeight: 600, textAlign: "center" }}>{item.label}</div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* T8: radial wipe */}
      {frame >= scene9Start - 20 && frame < scene9Start + 5 && (
        <div style={{ position: "absolute", inset: 0, background: "radial-gradient(circle at center, rgba(16,185,129,0.4), rgba(59,130,246,0.2))", clipPath: `circle(${t8wipe * 80}% at 50% 50%)`, opacity: 0.7 }} />
      )}

      {/* ══ SCENE 9: CTA ══ */}
      {frame >= scene9Start && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", opacity: s9opacity, gap: 40 }}>
          <div style={{ transform: `scale(${heartScale9 * heartbeat})` }}>
            <svg width="105" height="105" viewBox="0 0 100 100" style={{ filter: `drop-shadow(0 0 ${35 * glowPulse}px rgba(16,185,129,${glowPulse}))` }}>
              <path d="M50 85 C 20 60, 10 40, 10 28 C 10 15, 20 10, 28 10 C 36 10, 44 15, 50 25 C 56 15, 64 10, 72 10 C 80 10, 90 15, 90 28 C 90 40, 80 60, 50 85 Z" fill="#10b981" />
            </svg>
          </div>
          <div style={{ fontSize: 70, fontFamily: "'Epilogue',sans-serif", fontWeight: 700, color: "white", textAlign: "center", transform: `translateY(${headline9Y}px)`, opacity: headline9Opacity, lineHeight: 1.25, maxWidth: 1050 }}>
            Better outcomes.<br /><span style={{ color: "#10b981" }}>Healthier patients.</span>
          </div>
          <div style={{ fontSize: 36, fontFamily: "'DM Sans',sans-serif", fontWeight: 500, color: "rgba(255,255,255,0.78)", textAlign: "center", maxWidth: 900, lineHeight: 1.4, transform: `translateY(${sub9Y}px)`, opacity: sub9Opacity }}>
            From hospital to home, we're with them every step
          </div>
          <div style={{ marginTop: 10, padding: "22px 60px", fontSize: 36, fontFamily: "'Epilogue',sans-serif", fontWeight: 600, color: "#10b981", border: "2px solid #10b981", borderRadius: 18, transform: `scale(${cta9Scale})`, opacity: cta9Opacity, boxShadow: `0 0 50px rgba(16,185,129,${0.3 * glowPulse}),inset 0 0 30px rgba(16,185,129,${0.05 * glowPulse})`, backgroundColor: "rgba(16,185,129,0.1)" }}>
            adaptlyapp.com
          </div>
          <div style={{ fontSize: 22, fontFamily: "'DM Sans',sans-serif", color: "rgba(255,255,255,0.45)", fontWeight: 400, textAlign: "center", opacity: tag9Opacity }}>
            Empowering recovery through intelligent care coordination
          </div>
        </div>
      )}
    </div>
  );
};
