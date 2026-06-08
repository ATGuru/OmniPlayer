import { useState, useEffect, useRef } from "react";

const tracks = [
  { id: 1, title: "Break Their Gates", artist: "Sons of the Iron Tide", album: "Iron Tide Saga", duration: 247, bpm: 142 },
  { id: 2, title: "Rising Anyway", artist: "AllTechGuru", album: "Rising Anyway EP", duration: 203, bpm: 88 },
  { id: 3, title: "None Born Broken", artist: "Inner We", album: "Inner We LP", duration: 189, bpm: 95 },
  { id: 4, title: "GhostNode", artist: "AllTechGuru", album: "Inner We LP", duration: 224, bpm: 112 },
  { id: 5, title: "The Wanderer Returns", artist: "Sons of the Iron Tide", album: "Iron Tide Saga", duration: 312, bpm: 128 },
  { id: 6, title: "Flame to Breeze", artist: "Inner We", album: "Inner We LP", duration: 198, bpm: 78 },
];

function formatTime(s) {
  const m = Math.floor(s / 60);
  const sec = Math.floor(s % 60);
  return `${m}:${sec.toString().padStart(2, "0")}`;
}

function WaveformVisualizer({ isPlaying, color }) {
  const bars = 40;
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 2, height: 48, padding: "0 4px" }}>
      {Array.from({ length: bars }).map((_, i) => {
        const baseH = 8 + Math.sin(i * 0.6) * 12 + Math.cos(i * 0.3) * 8;
        return (
          <div
            key={i}
            style={{
              width: 3,
              height: baseH,
              background: color,
              borderRadius: 2,
              animation: isPlaying ? `wave ${0.6 + (i % 5) * 0.12}s ease-in-out infinite alternate` : "none",
              animationDelay: `${(i * 0.04).toFixed(2)}s`,
              opacity: 0.6 + (i % 3) * 0.13,
              transition: "height 0.3s ease",
            }}
          />
        );
      })}
    </div>
  );
}

function HoloPanel({ children, style, glowColor = "#00f5ff" }) {
  return (
    <div style={{
      background: "linear-gradient(135deg, rgba(0,245,255,0.04) 0%, rgba(180,0,255,0.06) 50%, rgba(255,0,180,0.04) 100%)",
      border: `1px solid rgba(0,245,255,0.18)`,
      borderRadius: 12,
      boxShadow: `0 0 24px rgba(0,245,255,0.08), inset 0 0 40px rgba(0,245,255,0.03), 0 0 1px ${glowColor}`,
      backdropFilter: "blur(12px)",
      position: "relative",
      overflow: "hidden",
      ...style,
    }}>
      <div style={{
        position: "absolute", inset: 0, pointerEvents: "none",
        background: "repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,245,255,0.015) 2px, rgba(0,245,255,0.015) 4px)",
        zIndex: 0,
      }} />
      <div style={{ position: "relative", zIndex: 1 }}>
        {children}
      </div>
    </div>
  );
}

function GlitchText({ text, style }) {
  const [glitching, setGlitching] = useState(false);
  useEffect(() => {
    const interval = setInterval(() => {
      setGlitching(true);
      setTimeout(() => setGlitching(false), 120);
    }, 4000 + Math.random() * 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <span style={{
      ...style,
      display: "inline-block",
      filter: glitching ? "hue-rotate(90deg) brightness(1.4)" : "none",
      transform: glitching ? "translateX(2px)" : "none",
      transition: "filter 0.05s, transform 0.05s",
      textShadow: glitching
        ? "2px 0 #ff00c8, -2px 0 #00f5ff"
        : style?.textShadow || "none",
    }}>
      {text}
    </span>
  );
}

function SpectrumRing({ isPlaying, size = 160 }) {
  const segments = 48;
  const cx = size / 2, cy = size / 2, r = size / 2 - 8;
  return (
    <svg width={size} height={size} style={{ position: "absolute", top: 0, left: 0 }}>
      {Array.from({ length: segments }).map((_, i) => {
        const angle = (i / segments) * Math.PI * 2 - Math.PI / 2;
        const len = isPlaying ? 6 + Math.sin(i * 0.8) * 8 : 4;
        const x1 = cx + Math.cos(angle) * (r - 2);
        const y1 = cy + Math.sin(angle) * (r - 2);
        const x2 = cx + Math.cos(angle) * (r - 2 + len);
        const y2 = cy + Math.sin(angle) * (r - 2 + len);
        const hue = (i / segments) * 120 + 180;
        return (
          <line key={i} x1={x1} y1={y1} x2={x2} y2={y2}
            stroke={`hsl(${hue}, 100%, 65%)`}
            strokeWidth={2} strokeLinecap="round"
            style={{
              animation: isPlaying ? `pulse ${0.5 + (i % 6) * 0.1}s ease-in-out infinite alternate` : "none",
              animationDelay: `${(i * 0.02).toFixed(2)}s`,
            }}
          />
        );
      })}
    </svg>
  );
}

export default function MP3Player() {
  const [currentTrack, setCurrentTrack] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [volume, setVolume] = useState(80);
  const [shuffle, setShuffle] = useState(false);
  const [repeat, setRepeat] = useState(false);
  const [showQueue, setShowQueue] = useState(false);
  const progressRef = useRef(null);
  const track = tracks[currentTrack];
  const elapsed = (progress / 100) * track.duration;

  useEffect(() => {
    let timer;
    if (isPlaying) {
      timer = setInterval(() => {
        setProgress(p => {
          if (p >= 100) {
            if (repeat) return 0;
            const next = (currentTrack + 1) % tracks.length;
            setCurrentTrack(next);
            return 0;
          }
          return p + (100 / track.duration) * 0.5;
        });
      }, 500);
    }
    return () => clearInterval(timer);
  }, [isPlaying, track.duration, currentTrack, repeat]);

  const skip = (dir) => {
    setProgress(0);
    if (shuffle) {
      let next;
      do { next = Math.floor(Math.random() * tracks.length); } while (next === currentTrack);
      setCurrentTrack(next);
    } else {
      setCurrentTrack((currentTrack + dir + tracks.length) % tracks.length);
    }
  };

  const handleProgressClick = (e) => {
    const rect = progressRef.current.getBoundingClientRect();
    const pct = ((e.clientX - rect.left) / rect.width) * 100;
    setProgress(Math.max(0, Math.min(100, pct)));
  };

  const cyan = "#00f5ff";
  const violet = "#b400ff";
  const magenta = "#ff00c8";

  return (
    <div style={{
      minHeight: "100vh",
      background: "#030508",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontFamily: "'Rajdhani', sans-serif",
      padding: 16,
      position: "relative",
      overflow: "hidden",
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Rajdhani:wght@300;400;600;700&display=swap');
        @keyframes wave { from { transform: scaleY(1); } to { transform: scaleY(2.4); } }
        @keyframes pulse { from { opacity: 0.4; } to { opacity: 1; } }
        @keyframes drift { 0%,100% { transform: translateY(0) rotate(0deg); } 50% { transform: translateY(-8px) rotate(0.5deg); } }
        @keyframes chromaShift { 0%,100% { filter: hue-rotate(0deg); } 50% { filter: hue-rotate(15deg); } }
        @keyframes orbitSpin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        @keyframes scanline { 0% { top: -10%; } 100% { top: 110%; } }
        @keyframes flicker { 0%,100% { opacity: 1; } 92% { opacity: 1; } 93% { opacity: 0.7; } 94% { opacity: 1; } }
        .track-row:hover { background: rgba(0,245,255,0.06) !important; }
        .ctrl-btn:hover { transform: scale(1.12); filter: brightness(1.4) drop-shadow(0 0 8px #00f5ff); }
        .ctrl-btn:active { transform: scale(0.94); }
        .icon-btn:hover { color: #00f5ff !important; }
        ::-webkit-scrollbar { width: 4px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: rgba(0,245,255,0.3); border-radius: 2px; }
      `}</style>

      {/* Ambient background orbs */}
      <div style={{ position: "fixed", inset: 0, pointerEvents: "none", zIndex: 0 }}>
        <div style={{ position: "absolute", width: 400, height: 400, borderRadius: "50%", background: "radial-gradient(circle, rgba(0,245,255,0.06) 0%, transparent 70%)", top: "10%", left: "5%", animation: "drift 8s ease-in-out infinite" }} />
        <div style={{ position: "absolute", width: 300, height: 300, borderRadius: "50%", background: "radial-gradient(circle, rgba(180,0,255,0.07) 0%, transparent 70%)", bottom: "15%", right: "8%", animation: "drift 11s ease-in-out infinite reverse" }} />
        <div style={{ position: "absolute", width: 200, height: 200, borderRadius: "50%", background: "radial-gradient(circle, rgba(255,0,200,0.05) 0%, transparent 70%)", top: "55%", left: "30%", animation: "drift 7s ease-in-out infinite 2s" }} />
        {/* Scanline sweep */}
        <div style={{ position: "absolute", left: 0, right: 0, height: 60, background: "linear-gradient(transparent, rgba(0,245,255,0.04), transparent)", animation: "scanline 6s linear infinite", pointerEvents: "none" }} />
      </div>

      <div style={{ position: "relative", zIndex: 1, width: "100%", maxWidth: 420, animation: "flicker 8s ease-in-out infinite" }}>

        {/* Header bar */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12, padding: "0 4px" }}>
          <span style={{ fontFamily: "Orbitron", fontSize: 11, color: cyan, letterSpacing: 4, opacity: 0.7 }}>OMNIX AUDIO</span>
          <div style={{ display: "flex", gap: 6 }}>
            {["●", "●", "●"].map((d, i) => (
              <span key={i} style={{ fontSize: 7, color: [cyan, violet, magenta][i], opacity: 0.8, textShadow: `0 0 6px ${[cyan, violet, magenta][i]}` }}>{d}</span>
            ))}
          </div>
          <span style={{ fontFamily: "Orbitron", fontSize: 11, color: magenta, letterSpacing: 2, opacity: 0.7 }}>v2.4.1</span>
        </div>

        {/* Main player card */}
        <HoloPanel style={{ padding: 24 }}>

          {/* Album art / visualizer */}
          <div style={{ display: "flex", justifyContent: "center", marginBottom: 24 }}>
            <div style={{ position: "relative", width: 160, height: 160 }}>
              <SpectrumRing isPlaying={isPlaying} size={160} />
              <div style={{
                position: "absolute", inset: 12,
                borderRadius: "50%",
                background: `conic-gradient(from 0deg, ${violet}, ${cyan}, ${magenta}, ${violet})`,
                padding: 3,
                animation: isPlaying ? "orbitSpin 8s linear infinite" : "none",
              }}>
                <div style={{
                  width: "100%", height: "100%", borderRadius: "50%",
                  background: "linear-gradient(135deg, #050a12 0%, #0a0f1e 100%)",
                  display: "flex", alignItems: "center", justifyContent: "center",
                  flexDirection: "column", gap: 4,
                }}>
                  <span style={{ fontSize: 32 }}>⟁</span>
                  <span style={{ fontFamily: "Orbitron", fontSize: 8, color: cyan, letterSpacing: 2, opacity: 0.6 }}>ATGURU</span>
                </div>
              </div>
              {/* Center dot */}
              <div style={{ position: "absolute", top: "50%", left: "50%", transform: "translate(-50%,-50%)", width: 10, height: 10, borderRadius: "50%", background: cyan, boxShadow: `0 0 12px ${cyan}`, zIndex: 2 }} />
            </div>
          </div>

          {/* Track info */}
          <div style={{ textAlign: "center", marginBottom: 20 }}>
            <GlitchText
              text={track.title}
              style={{
                fontFamily: "Orbitron", fontSize: 18, fontWeight: 700,
                color: "#fff", letterSpacing: 1,
                textShadow: `0 0 20px ${cyan}80`,
                display: "block", marginBottom: 4,
              }}
            />
            <div style={{ color: "rgba(0,245,255,0.6)", fontSize: 13, letterSpacing: 2, fontWeight: 600 }}>{track.artist}</div>
            <div style={{ color: "rgba(180,0,255,0.5)", fontSize: 11, letterSpacing: 1, marginTop: 2 }}>{track.album}</div>
            <div style={{ marginTop: 6, display: "flex", alignItems: "center", justifyContent: "center", gap: 12 }}>
              <span style={{ fontFamily: "Orbitron", fontSize: 9, color: magenta, opacity: 0.6, letterSpacing: 2 }}>{track.bpm} BPM</span>
              <span style={{ color: "rgba(255,255,255,0.15)", fontSize: 10 }}>◆</span>
              <span style={{ fontFamily: "Orbitron", fontSize: 9, color: cyan, opacity: 0.6, letterSpacing: 2 }}>MP3 · 320K</span>
            </div>
          </div>

          {/* Waveform */}
          <div style={{ marginBottom: 12, display: "flex", justifyContent: "center" }}>
            <WaveformVisualizer isPlaying={isPlaying} color={cyan} />
          </div>

          {/* Progress bar */}
          <div style={{ marginBottom: 8 }}>
            <div
              ref={progressRef}
              onClick={handleProgressClick}
              style={{ height: 4, background: "rgba(0,245,255,0.12)", borderRadius: 2, cursor: "pointer", position: "relative", marginBottom: 6 }}
            >
              <div style={{
                height: "100%", width: `${progress}%`,
                background: `linear-gradient(90deg, ${violet}, ${cyan})`,
                borderRadius: 2, position: "relative",
                boxShadow: `0 0 8px ${cyan}80`,
                transition: "width 0.4s linear",
              }}>
                <div style={{
                  position: "absolute", right: -4, top: "50%", transform: "translateY(-50%)",
                  width: 10, height: 10, borderRadius: "50%",
                  background: cyan, boxShadow: `0 0 10px ${cyan}`,
                }} />
              </div>
            </div>
            <div style={{ display: "flex", justifyContent: "space-between" }}>
              <span style={{ fontFamily: "Orbitron", fontSize: 10, color: "rgba(0,245,255,0.5)" }}>{formatTime(elapsed)}</span>
              <span style={{ fontFamily: "Orbitron", fontSize: 10, color: "rgba(0,245,255,0.3)" }}>{formatTime(track.duration)}</span>
            </div>
          </div>

          {/* Controls */}
          <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 20, marginBottom: 20 }}>
            <button className="icon-btn" onClick={() => setShuffle(!shuffle)} style={{ background: "none", border: "none", cursor: "pointer", color: shuffle ? cyan : "rgba(255,255,255,0.25)", fontSize: 16, transition: "color 0.2s", padding: 4 }}>⇌</button>
            <button className="ctrl-btn" onClick={() => skip(-1)} style={{ background: "none", border: "none", cursor: "pointer", color: "rgba(0,245,255,0.7)", fontSize: 24, transition: "all 0.15s", padding: 8 }}>⏮</button>

            {/* Play/Pause */}
            <button
              className="ctrl-btn"
              onClick={() => setIsPlaying(!isPlaying)}
              style={{
                width: 64, height: 64, borderRadius: "50%", border: `2px solid ${cyan}`,
                background: isPlaying
                  ? `radial-gradient(circle, ${cyan}22, transparent)`
                  : `radial-gradient(circle, ${violet}22, transparent)`,
                boxShadow: isPlaying ? `0 0 24px ${cyan}60, inset 0 0 16px ${cyan}20` : `0 0 12px ${violet}40`,
                cursor: "pointer", fontSize: 22, color: "#fff",
                display: "flex", alignItems: "center", justifyContent: "center",
                transition: "all 0.2s",
              }}
            >
              {isPlaying ? "⏸" : "▶"}
            </button>

            <button className="ctrl-btn" onClick={() => skip(1)} style={{ background: "none", border: "none", cursor: "pointer", color: "rgba(0,245,255,0.7)", fontSize: 24, transition: "all 0.15s", padding: 8 }}>⏭</button>
            <button className="icon-btn" onClick={() => setRepeat(!repeat)} style={{ background: "none", border: "none", cursor: "pointer", color: repeat ? magenta : "rgba(255,255,255,0.25)", fontSize: 16, transition: "color 0.2s", padding: 4 }}>↻</button>
          </div>

          {/* Volume */}
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 4 }}>
            <span style={{ color: "rgba(0,245,255,0.4)", fontSize: 14 }}>🔈</span>
            <div style={{ flex: 1, position: "relative", height: 3, background: "rgba(0,245,255,0.1)", borderRadius: 2, cursor: "pointer" }}
              onClick={e => {
                const r = e.currentTarget.getBoundingClientRect();
                setVolume(Math.round(((e.clientX - r.left) / r.width) * 100));
              }}>
              <div style={{ height: "100%", width: `${volume}%`, background: `linear-gradient(90deg, ${violet}80, ${magenta})`, borderRadius: 2, boxShadow: `0 0 6px ${magenta}60`, transition: "width 0.1s" }} />
            </div>
            <span style={{ fontFamily: "Orbitron", fontSize: 9, color: "rgba(180,0,255,0.5)", width: 28, textAlign: "right" }}>{volume}%</span>
            <span style={{ color: "rgba(255,0,200,0.5)", fontSize: 14 }}>🔊</span>
          </div>
        </HoloPanel>

        {/* Queue toggle */}
        <div style={{ display: "flex", justifyContent: "center", margin: "12px 0" }}>
          <button
            onClick={() => setShowQueue(!showQueue)}
            style={{
              background: "none", border: `1px solid rgba(0,245,255,0.2)`, borderRadius: 20,
              color: "rgba(0,245,255,0.5)", fontFamily: "Orbitron", fontSize: 9,
              letterSpacing: 3, padding: "6px 20px", cursor: "pointer",
              transition: "all 0.2s",
            }}
          >
            {showQueue ? "▲ HIDE QUEUE" : "▼ QUEUE"}
          </button>
        </div>

        {/* Queue */}
        {showQueue && (
          <HoloPanel style={{ padding: 8, maxHeight: 240, overflowY: "auto" }}>
            {tracks.map((t, i) => (
              <div
                key={t.id}
                className="track-row"
                onClick={() => { setCurrentTrack(i); setProgress(0); setIsPlaying(true); }}
                style={{
                  display: "flex", alignItems: "center", gap: 12, padding: "10px 12px",
                  borderRadius: 8, cursor: "pointer",
                  background: i === currentTrack ? "rgba(0,245,255,0.08)" : "transparent",
                  borderLeft: i === currentTrack ? `2px solid ${cyan}` : "2px solid transparent",
                  transition: "all 0.15s", marginBottom: 2,
                }}
              >
                <span style={{ fontFamily: "Orbitron", fontSize: 9, color: i === currentTrack ? cyan : "rgba(255,255,255,0.2)", width: 16, textAlign: "center" }}>
                  {i === currentTrack && isPlaying ? "▶" : String(i + 1).padStart(2, "0")}
                </span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ color: i === currentTrack ? "#fff" : "rgba(255,255,255,0.6)", fontSize: 13, fontWeight: 600, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{t.title}</div>
                  <div style={{ color: "rgba(0,245,255,0.35)", fontSize: 11 }}>{t.artist}</div>
                </div>
                <span style={{ fontFamily: "Orbitron", fontSize: 9, color: "rgba(0,245,255,0.3)" }}>{formatTime(t.duration)}</span>
              </div>
            ))}
          </HoloPanel>
        )}

        {/* Bottom status bar */}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 12, padding: "0 4px" }}>
          <span style={{ fontFamily: "Orbitron", fontSize: 9, color: "rgba(0,245,255,0.3)", letterSpacing: 2 }}>LOCAL LIBRARY</span>
          <div style={{ display: "flex", gap: 4, alignItems: "center" }}>
            <div style={{ width: 6, height: 6, borderRadius: "50%", background: isPlaying ? "#00ff88" : "rgba(255,255,255,0.2)", boxShadow: isPlaying ? "0 0 8px #00ff88" : "none" }} />
            <span style={{ fontFamily: "Orbitron", fontSize: 9, color: isPlaying ? "#00ff88" : "rgba(255,255,255,0.2)", letterSpacing: 1 }}>{isPlaying ? "PLAYING" : "STANDBY"}</span>
          </div>
          <span style={{ fontFamily: "Orbitron", fontSize: 9, color: "rgba(180,0,255,0.3)", letterSpacing: 2 }}>{tracks.length} TRACKS</span>
        </div>
      </div>
    </div>
  );
}
