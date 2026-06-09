"use client";

import { toast } from "sonner";

import { toastConfig } from "@/app.config";

/**
 * Notification API — preserves the original imperative notify/success/error/
 * warning/info surface (was zerodevx svelte-toast), now backed by sonner.
 *
 * Callable from anywhere (components or library code) without a hook, matching
 * the original NotificationToast helper.
 */
const duration = toastConfig.duration;

export function notify(message: string) {
  return toast(message, { duration });
}

export function success(message: string) {
  return toast.success(message, { duration });
}

export function error(message: string) {
  return toast.error(message, { duration });
}

export function warning(message: string) {
  return toast.warning(message, { duration });
}

export function info(message: string) {
  return toast.info(message, { duration });
}

export const notifications = { notify, success, error, warning, info };
