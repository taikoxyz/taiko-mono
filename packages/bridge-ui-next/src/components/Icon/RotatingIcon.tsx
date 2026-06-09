import Icon, { type IconType } from "./Icon";

export interface RotatingIconProps {
  loading: boolean;
  type: IconType;
  size?: number;
}

export default function RotatingIcon({
  loading,
  type,
  size = 20,
}: RotatingIconProps) {
  return (
    <>
      {/*
        Scoped keyframe ported verbatim from the original Svelte <style> block.
        The original used a component-scoped `.rotating` class:
          animation: rotation 2s infinite linear;
        Tailwind's `animate-spin` is 1s, so we keep the exact 2s timing instead.
      */}
      <style>{`
        @keyframes RotatingIcon_rotation {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        .RotatingIcon_rotating {
          animation: RotatingIcon_rotation 2s infinite linear;
        }
      `}</style>
      <div className={loading ? "RotatingIcon_rotating" : ""}>
        <Icon type={type} size={size} />
      </div>
    </>
  );
}
