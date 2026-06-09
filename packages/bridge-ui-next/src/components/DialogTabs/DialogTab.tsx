"use client";

import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

import styles from "./DialogTab.module.css";

export interface DialogTabProps {
  active: boolean;
  /** Fired when the tab button is clicked (Svelte `on:click` -> `onClick`). */
  onClick?: () => void;
  /** Default slot content (the tab title). */
  children?: ReactNode;
}

export default function DialogTab({
  active,
  onClick,
  children,
}: DialogTabProps) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      // Global daisyUI base classes (`tab` / `tab-active`) preserve the original
      // appearance; the CSS-module classes reproduce the component-scoped
      // <style> overrides. `!border-color-red` is kept verbatim from the source.
      className={cn(
        "tab !border-color-red",
        styles.tab,
        active && "tab-active",
        active && styles["tab-active"],
      )}
      onClick={onClick}
    >
      {children}
    </button>
  );
}
