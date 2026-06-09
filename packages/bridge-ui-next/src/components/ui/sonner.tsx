"use client";

import { Toaster as Sonner, type ToasterProps } from "sonner";

import { Theme, useThemeStore } from "@/stores/useThemeStore";

/**
 * Themed sonner Toaster. Reads the app theme store (data-theme driven) so toasts
 * match light/dark. The global instance is mounted in providers.tsx; this wrapper
 * is exported for any local usage and to keep the shadcn convention (@/components/ui/sonner).
 */
const Toaster = ({ ...props }: ToasterProps) => {
  const theme = useThemeStore((s) => s.theme);
  return (
    <Sonner
      theme={theme === Theme.DARK ? "dark" : "light"}
      className="toaster group"
      {...props}
    />
  );
};

export { Toaster };
