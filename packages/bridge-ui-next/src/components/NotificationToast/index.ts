// Mirrors src/components/NotificationToast/index.ts.
//
// The original re-exported the `NotificationToast` Svelte component (the toast
// host) plus the imperative toast helpers. We preserve that surface: the
// `NotificationToast` component is the sonner `<Toaster>` host (mounted in
// app/providers.tsx) and ItemToast is the per-toast body rendered via
// toast.custom. The imperative helpers (notify/success/error/warning/info) are
// the public API callers depend on (e.g. AccountConnectionToast,
// libs/bridge/handleBridgeErrors).
export { default, default as NotificationToast } from "./NotificationToast";
export { default as ItemToast } from "./ItemToast";
export type { ItemToastProps } from "./ItemToast";
export {
  notify,
  successToast,
  errorToast,
  warningToast,
  infoToast,
} from "./toast";
export type { NotificationType } from "./toast";
export type { TypeToast } from "./types";
