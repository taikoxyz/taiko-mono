"use client";

import { useEffect } from "react";

import {
  applyTheme,
  resolveInitialTheme,
  useThemeStore,
} from "@/stores/useThemeStore";

/**
 * ThemeController — keeps the Zustand theme store in sync with the actual
 * <html data-theme> attribute set by the inline FOUC script in layout.tsx.
 *
 * On mount it reconciles the store with the resolved initial theme (localStorage
 * or prefers-color-scheme) so the toggle button starts from the correct state,
 * then applies any subsequent store changes to the DOM. Renders nothing.
 */
export default function ThemeController() {
  const theme = useThemeStore((s) => s.theme);
  const setTheme = useThemeStore((s) => s.setTheme);

  // Reconcile store -> resolved initial theme once on mount (client-only).
  useEffect(() => {
    const initial = resolveInitialTheme();
    setTheme(initial);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Apply store changes to the DOM.
  useEffect(() => {
    applyTheme(theme);
  }, [theme]);

  return null;
}
