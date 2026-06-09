import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

/**
 * Merge conditional Tailwind class strings, de-duplicating conflicting utilities.
 * Use for every conditional className in migrated components.
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
