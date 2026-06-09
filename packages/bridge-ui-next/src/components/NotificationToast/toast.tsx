"use client";

// Ported from the `context="module"` block of
// src/components/NotificationToast/NotificationToast.svelte.
//
// The original was backed by @zerodevx/svelte-toast and rendered a fully
// custom ItemToast component inside each toast (the chrome of the underlying
// toast lib was stripped via CSS vars so ItemToast controls 100% of the look).
// In the Next app, toasts are hosted by sonner (the <NotificationToast />
// Toaster, mounted in providers.tsx). We reproduce the original behaviour with
// sonner's `toast.custom`, which renders an arbitrary React element as the toast
// body — giving us the exact ItemToast appearance for pixel parity.
//
// Public surface preserved verbatim from the original module script:
//   notify({ title, message?, type?, closeManually? })
//   successToast / errorToast / warningToast / infoToast
//
// `closeManually` (default true for error/warning, false otherwise) kept the
// toast open until dismissed (original passed `initial: 0` to svelte-toast, i.e.
// no auto-dismiss). sonner's `duration: Infinity` reproduces that. `close` maps
// to `toast.dismiss(id)` — the same role as the original `toast.pop(id)`.
//
// NOTE: this file is .tsx because sonner's `toast.custom` requires its render
// callback to return a `React.ReactElement`. Under React 19's types,
// `createElement(...)` yields a `FunctionComponentElement` whose `type` widens
// to a component returning `ReactNode | Promise<ReactNode>`, which is not
// assignable to that `ReactElement`. Emitting JSX produces a plain, correctly
// typed `ReactElement` and avoids a cast.

import { toast } from "sonner";

import { toastConfig } from "@/app.config";

import ItemToast from "./ItemToast";
import type { TypeToast } from "./types";

export type NotificationType = {
  title: string;
  message?: string;
  type?: TypeToast;
  closeManually?: boolean;
};

const duration = toastConfig.duration;

const closeManuallyDefaults: Record<TypeToast, boolean> = {
  // Defaults when no value was provided for closeManually
  success: false,
  error: true,
  warning: true,
  info: false,
  unknown: false,
};

function getDefaultCloseBehaviour(type: TypeToast): boolean {
  return closeManuallyDefaults[type];
}

export function notify(notificationType: NotificationType) {
  const {
    title,
    message,
    type = "unknown",
    closeManually = getDefaultCloseBehaviour(type),
  } = notificationType;

  return toast.custom(
    (id) => (
      <ItemToast
        type={type}
        title={title}
        message={message}
        close={() => toast.dismiss(id)}
      />
    ),
    {
      // closeManually -> no auto-dismiss (original passed `initial: 0`).
      duration: closeManually ? Infinity : duration,
    },
  );
}

export function successToast(notificationType: NotificationType) {
  notify({
    ...notificationType,
    type: "success",
  });
}

export function errorToast(notificationType: NotificationType) {
  notify({
    ...notificationType,
    type: "error",
  });
}

export function warningToast(notificationType: NotificationType) {
  notify({
    ...notificationType,
    type: "warning",
  });
}

export function infoToast(notificationType: NotificationType) {
  notify({
    ...notificationType,
    type: "info",
  });
}
