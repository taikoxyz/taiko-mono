import type { ReactNode } from "react";

export interface PageProps {
  /** Default slot content. */
  children?: ReactNode;
}

/**
 * React port of `components/Page/Page.svelte`.
 *
 * Pure presentational layout wrapper. The Svelte source is a single `<div>` with a
 * default `<slot />`; the DOM structure and Tailwind class string are copied verbatim
 * for pixel parity. No state/effects/refs/browser APIs, so this stays a server
 * component (no 'use client').
 */
export default function Page({ children }: PageProps) {
  return (
    <div className="f-center w-full px-0 md:px-10 md:py-[40px]">{children}</div>
  );
}
