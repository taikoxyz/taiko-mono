"use client";

import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";

export enum Theme {
  DARK = "dark",
  LIGHT = "light",
}

interface ThemeState {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  toggleTheme: () => void;
}

/**
 * Theme store — ported from stores/theme.ts.
 *
 * Persisted to localStorage under key 'theme' (matching the original FOUC script
 * and web3modal themeMode reader). Default DARK. The persisted value is a raw
 * 'dark' | 'light' string (NOT JSON-wrapped) so it stays compatible with the
 * inline <head> FOUC script and `localStorage.getItem('theme')` reads elsewhere.
 */
export const useThemeStore = create<ThemeState>()(
  persist(
    (set, get) => ({
      theme: Theme.DARK,
      setTheme: (theme) => {
        set({ theme });
        applyTheme(theme);
      },
      toggleTheme: () => {
        const next = get().theme === Theme.DARK ? Theme.LIGHT : Theme.DARK;
        set({ theme: next });
        applyTheme(next);
      },
    }),
    {
      name: "theme",
      // Store the bare 'dark' | 'light' string under localStorage 'theme'
      // so it interops with the FOUC script and web3modal.
      storage: createJSONStorage(() => ({
        getItem: (name) => {
          if (typeof window === "undefined") return null;
          const value = window.localStorage.getItem(name);
          if (!value) return null;
          // Wrap the raw string into the shape zustand/persist expects.
          return JSON.stringify({ state: { theme: value }, version: 0 });
        },
        setItem: (name, value) => {
          if (typeof window === "undefined") return;
          try {
            const parsed = JSON.parse(value) as { state?: { theme?: Theme } };
            const theme = parsed?.state?.theme ?? Theme.DARK;
            window.localStorage.setItem(name, theme);
          } catch {
            window.localStorage.setItem(name, Theme.DARK);
          }
        },
        removeItem: (name) => {
          if (typeof window === "undefined") return;
          window.localStorage.removeItem(name);
        },
      })),
    },
  ),
);

/** Apply the theme to <html data-theme>; client-only. */
export function applyTheme(theme: Theme) {
  if (typeof document === "undefined") return;
  document.documentElement.setAttribute("data-theme", theme);
}

/**
 * Resolve the initial theme from localStorage or prefers-color-scheme,
 * mirroring the original app.html FOUC logic. Client-only.
 */
export function resolveInitialTheme(): Theme {
  if (typeof window === "undefined") return Theme.DARK;
  const stored = window.localStorage.getItem("theme");
  if (stored && stored.toLowerCase() === "dark") return Theme.DARK;
  if (stored && stored.toLowerCase() === "light") return Theme.LIGHT;
  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? Theme.DARK
    : Theme.LIGHT;
}
