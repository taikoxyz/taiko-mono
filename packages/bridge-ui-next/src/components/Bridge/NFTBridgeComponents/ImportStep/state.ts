"use client";

import { useStore } from "zustand";
import { createStore } from "zustand/vanilla";

import { ImportMethod } from "@/components/Bridge/types";

/**
 * Ported from components/Bridge/NFTBridgeComponents/ImportStep/state.ts.
 *
 * The original `writable<ImportMethod>(ImportMethod.NONE)` becomes a VANILLA
 * zustand store (matching the `$components/Bridge/state` convention) so the
 * svelte idioms map 1:1:
 *   get(selectedImportMethod)            -> selectedImportMethod.getState()
 *   $selectedImportMethod = v            -> selectedImportMethod.setState(v)
 *
 * React components subscribe via `useSelectedImportMethod()` (mirrors `$store`).
 */
export const selectedImportMethod = createStore<ImportMethod>(
  () => ImportMethod.NONE,
);

/** React hook bound to the vanilla `selectedImportMethod` store. */
export function useSelectedImportMethod<T = ImportMethod>(
  selector: (state: ImportMethod) => T = (s) => s as unknown as T,
): T {
  return useStore(selectedImportMethod, selector);
}
