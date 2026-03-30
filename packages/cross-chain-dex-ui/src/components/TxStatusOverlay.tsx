import React, { useEffect, useRef, useState } from 'react';
import { TxOverlayPhase, TxOverlayState } from '../types';
import { EXPLORER_URL } from '../lib/constants';

// ─── Step definitions ────────────────────────────────────────────────────────

type ActivePhase = Exclude<TxOverlayPhase, 'idle' | 'rejected'>;

interface StepDef {
  phase: ActivePhase;
  label: string;
  color: string;
}

const STEPS: StepDef[] = [
  { phase: 'signing',    label: 'Signing',              color: '#fbbf24' },
  { phase: 'sequencing', label: 'Sequencing',           color: '#60a5fa' },
  { phase: 'proving',    label: 'Generating ZK Proof',  color: '#a78bfa' },
  { phase: 'proposing',  label: 'Submitting Block',     color: '#10b981' },
  { phase: 'complete',   label: 'Execution Complete',   color: '#34d399' },
];

const PHASE_TO_IDX: Partial<Record<TxOverlayPhase, number>> = {
  signing: 0, sequencing: 1, proving: 2, proposing: 3, complete: 4,
};

// px widths — used in both the circles row and the labels row so they stay aligned
const NODE_W    = 108;
const CONN_W    = 72;

// ─── Proof time helpers ───────────────────────────────────────────────────────

function formatDuration(ms: number): string {
  const s = ms / 1000;
  if (s < 60) return `${s.toFixed(1)}s`;
  const m = Math.floor(s / 60);
  return `${m}m ${Math.floor(s % 60)}s`;
}

// ─── Chevron connector ────────────────────────────────────────────────────────
// Three cascading ">" marks: leftmost = most opaque, rightmost = most faded,
// giving a directional-flow feel. Glows when the step to the left is done.

function ChevronConnector({ filled, color }: { filled: boolean; color: string }) {
  const CHEVRONS = [
    { pts: '1,1 6,7 1,13',   opFilled: 1.00, opEmpty: 0.14 },
    { pts: '9,1 14,7 9,13',  opFilled: 0.58, opEmpty: 0.09 },
    { pts: '17,1 22,7 17,13',opFilled: 0.26, opEmpty: 0.04 },
  ];

  return (
    <div style={{ width: CONN_W, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <svg
        viewBox="0 0 24 14"
        style={{
          width: 28, height: 16,
          overflow: 'visible',
          filter: filled ? `drop-shadow(0 0 5px ${color}90)` : 'none',
          transition: 'filter 0.55s ease',
        }}
      >
        {CHEVRONS.map(({ pts, opFilled, opEmpty }, i) => (
          <polyline
            key={i}
            points={pts}
            fill="none"
            stroke={filled ? color : '#1c2a3a'}
            strokeWidth="1.9"
            strokeLinecap="round"
            strokeLinejoin="round"
            style={{
              opacity: filled ? opFilled : opEmpty,
              transition: 'opacity 0.55s ease, stroke 0.55s ease',
            }}
          />
        ))}
      </svg>
    </div>
  );
}

// ─── Node icons (for the active spinning state) ───────────────────────────────

function NodeIcon({ phase, color }: { phase: ActivePhase; color: string }) {
  const s = { width: 40, height: 40 };
  if (phase === 'signing') return (
    <svg viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2"
      strokeLinecap="round" strokeLinejoin="round" style={s}>
      <path d="M12 20h9" /><path d="M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4 9.5-9.5z" />
    </svg>
  );
  if (phase === 'sequencing') return (
    <svg viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2"
      strokeLinecap="round" strokeLinejoin="round" style={s}>
      <polygon points="12 2 2 7 12 12 22 7 12 2" />
      <polyline points="2 17 12 22 22 17" /><polyline points="2 12 12 17 22 12" />
    </svg>
  );
  if (phase === 'proving') return (
    <svg viewBox="0 0 24 24" fill={color} style={s}>
      <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
    </svg>
  );
  if (phase === 'proposing') return (
    <svg viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2"
      strokeLinecap="round" strokeLinejoin="round" style={s}>
      <path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z" />
      <polyline points="3.27 6.96 12 12.01 20.73 6.96" /><line x1="12" y1="22.08" x2="12" y2="12" />
    </svg>
  );
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5"
      strokeLinecap="round" strokeLinejoin="round" style={s}>
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

// ─── Node circle variants ─────────────────────────────────────────────────────

type NodeStatus = 'done' | 'active' | 'pending';

function NodeCircle({ phase, status, color }: { phase: ActivePhase; status: NodeStatus; color: string }) {
  const base: React.CSSProperties = {
    width: NODE_W, height: NODE_W, borderRadius: '50%',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    flexShrink: 0,
  };

  if (status === 'done') {
    return (
      <div style={{ ...base, background: `${color}18`, border: `2px solid ${color}65` }}>
        <svg viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5"
          strokeLinecap="round" strokeLinejoin="round" style={{ width: 48, height: 48 }}>
          <polyline points="20 6 9 17 4 12" />
        </svg>
      </div>
    );
  }

  if (status === 'active') {
    return (
      <div style={{ position: 'relative', width: NODE_W, height: NODE_W }}>
        {/* Pulse rings — absolutely positioned, overflow doesn't affect layout */}
        <div style={{
          position: 'absolute', inset: -16, borderRadius: '50%',
          border: `1.5px solid ${color}45`,
          animation: 'pulseRing 2.1s ease-out infinite',
          pointerEvents: 'none',
        }} />
        <div style={{
          position: 'absolute', inset: -8, borderRadius: '50%',
          border: `1.5px solid ${color}30`,
          animation: 'pulseRing 2.1s ease-out 0.6s infinite',
          pointerEvents: 'none',
        }} />
        {/* Spinning outer ring */}
        <div style={{
          position: 'absolute', inset: 0, borderRadius: '50%',
          border: `2px solid ${color}18`,
          borderTop: `2px solid ${color}`,
          animation: 'spin 0.85s linear infinite',
        }} />
        {/* Inner glow disc + icon */}
        <div style={{
          position: 'absolute', inset: 10, borderRadius: '50%',
          background: `${color}0e`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <NodeIcon phase={phase} color={color} />
        </div>
      </div>
    );
  }

  // pending — show the step icon at low opacity so the upcoming step is recognisable
  return (
    <div style={{ ...base, background: '#080f17', border: '2px solid #1e3248' }}>
      <div style={{ opacity: 0.28 }}>
        <NodeIcon phase={phase} color={color} />
      </div>
    </div>
  );
}

// ─── Main overlay ─────────────────────────────────────────────────────────────

interface TxStatusOverlayProps {
  state: TxOverlayState;
  onClose: () => void;
}

export function TxStatusOverlay({ state, onClose }: TxStatusOverlayProps) {
  const provingStartRef  = useRef<number | null>(null);
  const prevPhaseRef     = useRef<TxOverlayPhase>('idle');
  const [provingDuration, setProvingDuration] = useState<number | null>(null);

  useEffect(() => {
    const prev = prevPhaseRef.current;
    const curr = state.phase;

    if (curr === 'proving' && prev !== 'proving') {
      provingStartRef.current = Date.now();
    } else if (prev === 'proving' && curr !== 'proving' && provingStartRef.current !== null) {
      setProvingDuration(Date.now() - provingStartRef.current);
      provingStartRef.current = null;
    }

    if (curr === 'idle') {
      setProvingDuration(null);
      provingStartRef.current = null;
    }

    prevPhaseRef.current = curr;
  }, [state.phase]);

  if (state.phase === 'idle') return null;

  const currentIdx = PHASE_TO_IDX[state.phase] ?? 0;
  const isInProgress = !['complete', 'rejected'].includes(state.phase);
  const activeColor = STEPS[currentIdx]?.color ?? '#10b981';

  // ── Rejected view ─────────────────────────────────────────────────────────
  if (state.phase === 'rejected') {
    return (
      <Backdrop>
        <Card>
          <div style={{ padding: '40px 32px 32px', textAlign: 'center' }}>
            <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 20 }}>
              <div style={{
                width: 72, height: 72, borderRadius: '50%',
                border: '2.5px solid #ef4444', background: '#ef444414',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg viewBox="0 0 24 24" fill="none" stroke="#ef4444" strokeWidth="2.5"
                  strokeLinecap="round" style={{ width: 34, height: 34 }}>
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </div>
            </div>
            <p style={{ color: '#f1f5f9', fontWeight: 600, fontSize: 18, marginBottom: 8, fontFamily: 'inherit' }}>
              Transaction Failed
            </p>
            {state.errorMessage && (
              <p style={{ color: '#94a3b8', fontSize: 14, marginBottom: 24, fontFamily: 'inherit', lineHeight: 1.5 }}>
                {state.errorMessage}
              </p>
            )}
            <button
              onClick={onClose}
              className="w-full py-3 rounded-xl text-sm font-medium bg-surge-card border border-surge-border/50 text-white hover:bg-surge-border/50 transition-colors"
            >
              Close
            </button>
          </div>
        </Card>
      </Backdrop>
    );
  }

  // ── Timeline view ─────────────────────────────────────────────────────────
  return (
    <Backdrop>
      <Card>
        <div style={{ padding: '24px 48px 40px' }}>

          {/* Header */}
          <p style={{
            textAlign: 'center',
            fontSize: 14,
            fontWeight: 500,
            letterSpacing: '0.12em',
            textTransform: 'uppercase',
            color: '#475569',
            marginBottom: 44,
            fontFamily: 'inherit',
          }}>
            {isInProgress ? 'Transaction in Progress' : 'Transaction Complete'}
          </p>

          {/* ── Circles row ── */}
          <div style={{ display: 'flex', alignItems: 'center' }}>
            {STEPS.map((step, i) => {
              const status: NodeStatus =
                (!isInProgress || i < currentIdx) ? 'done' :
                i === currentIdx ? 'active' : 'pending';
              return (
                <React.Fragment key={step.phase}>
                  <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
                    <NodeCircle phase={step.phase} status={status} color={step.color} />
                  </div>
                  {i < STEPS.length - 1 && (
                    <ChevronConnector filled={!isInProgress || i < currentIdx} color={step.color} />
                  )}
                </React.Fragment>
              );
            })}
          </div>

          {/* ── Labels row — uses matching spacers so labels center under their circles ── */}
          <div style={{ display: 'flex', marginTop: 20 }}>
            {STEPS.map((step, i) => {
              const status: NodeStatus =
                (!isInProgress || i < currentIdx) ? 'done' :
                i === currentIdx ? 'active' : 'pending';
              return (
                <React.Fragment key={step.phase}>
                  <div style={{ flex: 1, textAlign: 'center' }}>
                    <span style={{
                      fontSize: 20,
                      fontWeight: status === 'active' ? 600 : 400,
                      color: status === 'pending' ? '#2e4a62' : step.color,
                      letterSpacing: '0.01em',
                      fontFamily: 'inherit',
                      whiteSpace: 'normal',
                      lineHeight: 1.3,
                      transition: 'color 0.4s ease',
                      display: 'block',
                    }}>
                      {step.label}
                    </span>
                    {/* Proof duration badge — only for proving step once it's done */}
                    {step.phase === 'proving' && status === 'done' && provingDuration != null && (
                      <div className="animate-fade-up" style={{
                        display: 'inline-flex', alignItems: 'center', gap: 5,
                        marginTop: 8,
                        padding: '4px 12px',
                        borderRadius: 999,
                        background: `${step.color}18`,
                        border: `1.5px solid ${step.color}50`,
                      }}>
                        <svg viewBox="0 0 16 16" style={{ width: 15, height: 15 }} fill="none">
                          <circle cx="8" cy="9" r="5.5" stroke={step.color} strokeWidth="1.5" />
                          <line x1="6" y1="3.5" x2="10" y2="3.5" stroke={step.color} strokeWidth="1.5" strokeLinecap="round" />
                          <line x1="8" y1="3.5" x2="8" y2="4.5" stroke={step.color} strokeWidth="1.5" strokeLinecap="round" />
                          <polyline points="8,9 8,6.5 10.5,8" stroke={step.color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                        </svg>
                        <span style={{ fontSize: 17, fontWeight: 700, color: step.color, fontFamily: 'inherit', letterSpacing: '-0.02em' }}>
                          {formatDuration(provingDuration)}
                        </span>
                      </div>
                    )}
                  </div>
                  {/* Invisible spacer keeps labels aligned with circles above */}
                  {i < STEPS.length - 1 && <div style={{ width: CONN_W, flexShrink: 0 }} />}
                </React.Fragment>
              );
            })}
          </div>

          {/* ── Complete buttons ── */}
          {state.phase === 'complete' && (
            <div className="animate-fade-up" style={{ display: 'flex', gap: 12, marginTop: 32 }}>
                {state.txHash && (
                  <a
                    href={`${EXPLORER_URL}/tx/${state.txHash}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{
                      flex: 1,
                      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                      padding: '14px 20px',
                      borderRadius: 14,
                      border: `1.5px solid ${activeColor}55`,
                      color: activeColor,
                      background: `${activeColor}0e`,
                      fontFamily: 'inherit',
                      fontSize: 15,
                      fontWeight: 600,
                      textDecoration: 'none',
                      transition: 'background 0.2s ease, border-color 0.2s ease',
                      letterSpacing: '-0.01em',
                    }}
                    onMouseEnter={e => {
                      (e.currentTarget as HTMLAnchorElement).style.background = `${activeColor}1e`;
                      (e.currentTarget as HTMLAnchorElement).style.borderColor = `${activeColor}90`;
                    }}
                    onMouseLeave={e => {
                      (e.currentTarget as HTMLAnchorElement).style.background = `${activeColor}0e`;
                      (e.currentTarget as HTMLAnchorElement).style.borderColor = `${activeColor}55`;
                    }}
                  >
                    {/* External link icon */}
                    <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8"
                      strokeLinecap="round" strokeLinejoin="round" style={{ width: 16, height: 16 }}>
                      <path d="M11 3h6v6" /><path d="M17 3l-8 8" />
                      <path d="M9 5H4a1 1 0 00-1 1v10a1 1 0 001 1h10a1 1 0 001-1v-5" />
                    </svg>
                    View on Explorer
                  </a>
                )}
                <button
                  onClick={onClose}
                  className="bg-gradient-to-r from-surge-primary to-surge-secondary text-white hover:shadow-lg hover:shadow-surge-primary/30 hover:scale-[1.02] active:scale-[0.98] transition-all"
                  style={{
                    flex: 1,
                    padding: '14px 20px',
                    borderRadius: 14,
                    border: 'none',
                    fontFamily: 'inherit',
                    fontSize: 15,
                    fontWeight: 600,
                    cursor: 'pointer',
                    letterSpacing: '-0.01em',
                  }}
                >
                  Close
                </button>
            </div>
          )}

        </div>
      </Card>
    </Backdrop>
  );
}

// ─── Layout helpers ───────────────────────────────────────────────────────────

function Backdrop({ children }: { children: React.ReactNode }) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ backgroundColor: 'rgba(3, 5, 8, 0.92)' }}
    >
      {children}
    </div>
  );
}

function Card({ children }: { children: React.ReactNode }) {
  return (
    <div
      className="w-full mx-4"
      style={{
        maxWidth: 1000,
        background: 'linear-gradient(180deg, #090d12 0%, #07090d 100%)',
        border: '1px solid rgba(24, 32, 48, 0.9)',
        borderRadius: 24,
        boxShadow:
          'inset 0 1px 0 rgba(255, 255, 255, 0.04), 0 32px 64px rgba(0, 0, 0, 0.8), 0 0 60px rgba(16, 185, 129, 0.06)',
      }}
    >
      {children}
    </div>
  );
}
