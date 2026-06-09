"use client";

import type { ReactNode } from "react";

import { useMediaQuery } from "@/hooks/useResponsive";
import { cn } from "@/lib/utils";

/**
 * Base class string copied verbatim from the original Card.svelte for pixel parity.
 *
 * NOTE: the `light:md:` prefix relies on the daisyUI-generated `light:` variant from
 * the original Tailwind config. The bridge-ui-next Tailwind config does not (yet) wire
 * daisyUI, so a `light:` variant must be registered for the light-theme gradient to
 * apply. See the migration TODO. The string is preserved exactly so it "just works"
 * once that variant exists.
 */
const styles = `
    w-full
    md:card
    md:rounded-[20px]
    md:border
    md:border-divider-border
    md:glassy-gradient-card
    dark:md:dark-glass-background-gradient
    light:md:light-glass-background-gradient
    `;

export interface CardProps {
  /** Optional card heading rendered as an <h2>. */
  title?: string;
  /** Optional secondary paragraph text below the title. */
  text?: string;
  /** Pass-through className merged onto the outer wrapper (Svelte `$$props.class`). */
  className?: string;
  /** Default slot content. */
  children?: ReactNode;
}

/**
 * React port of `components/Card/Card.svelte`.
 *
 * Mirrors the original DOM structure exactly. The `data-glow-border` attribute is
 * applied only at desktop width (>=768px) — the original used the renderless
 * `<DesktopOrLarger bind:is />` component, which is functionally identical to the
 * `useMediaQuery('(min-width: 768px)')` hook used here (both start `false` on first
 * paint / SSR, then resolve from `window.matchMedia`).
 */
export default function Card({
  title = "",
  text = "",
  className,
  children,
}: CardProps) {
  const isDesktopOrLarger = useMediaQuery("(min-width: 768px)");

  const dynamicAttrs = isDesktopOrLarger ? { "data-glow-border": true } : {};

  const classes = cn(styles, className);

  return (
    <div className={classes}>
      <div
        {...dynamicAttrs}
        className="card-body body-regular px-4 md:p-[50px] gap-0 py-0 md:mt-[0px] mt-[40px]"
      >
        {title ? (
          <h2 className="card-title title-screen-bold">{title}</h2>
        ) : null}
        {text ? <p className="text-secondary-content">{text}</p> : null}
        <div className="f-col">{children}</div>
      </div>
    </div>
  );
}
