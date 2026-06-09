"use client";

import { Toaster } from "sonner";

import { Theme, useThemeStore } from "@/stores/useThemeStore";

/**
 * Notification toast host.
 *
 * Ported from the instance `<script>`/markup of
 * src/components/NotificationToast/NotificationToast.svelte, which mounted a
 * <SvelteToast> inside a `.NotificationToast` wrapper whose CSS variables both
 * (a) positioned the toast container and (b) stripped all of the toast lib's
 * own chrome so the embedded ItemToast controls 100% of the appearance.
 *
 * Here the host is sonner. We reproduce the original behaviour:
 *   - toasts are `unstyled` (sonner renders no background/padding/border of its
 *     own) — the equivalent of the original `--toastBackground: transparent`,
 *     `--toastPadding: 0`, `--toastBarWidth: 0`, `--toastBtn*: 0`, etc. ItemToast
 *     (via toast.custom) supplies the entire visual.
 *   - `--width: 339px` matches the original `--toastWidth: 339px`.
 *   - positioning matches the original CSS-var media queries exactly:
 *       default (mobile): top 77px, horizontally centered
 *       sm (>=640px):     top 77px, right 1rem
 *       md (>=768px):     top 77px, right 2.5rem
 *     (sonner's built-in mobile breakpoint is 600px, so we drive positioning
 *      with our own scoped CSS at the original 640px/768px breakpoints instead
 *      of sonner's mobile-offset mechanism.)
 *
 * Duration is applied per-toast in ./toast (toastConfig.duration), matching the
 * original `options = { duration: toastConfig.duration }`.
 *
 * The single global instance is mounted in app/providers.tsx.
 */
export default function NotificationToast() {
  const theme = useThemeStore((s) => s.theme);

  return (
    <div className="NotificationToast">
      <Toaster
        theme={theme === Theme.DARK ? "dark" : "light"}
        position="top-center"
        offset={77}
        gap={8}
        toastOptions={{
          unstyled: true,
          // The custom ItemToast fills the full width; sonner's --width drives
          // the container width (339px, matching --toastWidth in the original).
          style: { width: "339px" },
        }}
      />

      {/*
        Scoped positioning override reproducing the original `.NotificationToast`
        CSS-variable media queries. Targets sonner's toaster container which lives
        as a descendant of `.NotificationToast`.
      */}
      <style>{`
        .NotificationToast [data-sonner-toaster] {
          --width: 339px;
        }
        /* default (mobile): centered horizontally, top 77px (sonner top-center). */

        /* sm */
        @media (min-width: 640px) {
          .NotificationToast [data-sonner-toaster][data-x-position='center'] {
            left: auto;
            right: 1rem;
            transform: none;
          }
        }
        /* md */
        @media (min-width: 768px) {
          .NotificationToast [data-sonner-toaster][data-x-position='center'] {
            right: 2.5rem;
          }
        }
      `}</style>
    </div>
  );
}
