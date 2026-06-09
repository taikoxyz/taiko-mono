"use client";

import { useEffect, useRef } from "react";

import { cn } from "@/lib/utils";

export interface LoadingTextProps {
  /** The placeholder text used as the skeleton mask. */
  mask?: string;
  /** Additional classes merged onto the mask span (mirrors Svelte `class`). */
  className?: string;
}

export default function LoadingText({
  mask = "Loading",
  className,
}: LoadingTextProps) {
  const maskElem = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const el = maskElem.current;
    if (!el) return;
    // The idea is to use same background color as text color
    const textColor = globalThis.getComputedStyle(el).getPropertyValue("color");
    el.style.backgroundColor = textColor;
  }, []);

  return (
    <span ref={maskElem} className={cn("animate-pulse rounded-md", className)}>
      {mask}
    </span>
  );
}
