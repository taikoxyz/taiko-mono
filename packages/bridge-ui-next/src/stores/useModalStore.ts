"use client";

import { createStore } from "zustand/vanilla";
import { useStore } from "zustand";

/**
 * Modal UI store — ported from stores/modal.ts (switchChainModal, bridgePausedModal).
 *
 * Backed by a VANILLA zustand store so non-React library callers
 * (libs/wagmi/watcher.ts, libs/util/checkForPausedContracts.ts) can do
 * `modalStore.getState().setSwitchChainModal(true)` without a hook.
 */
interface ModalState {
  switchChainModal: boolean;
  bridgePausedModal: boolean;
  setSwitchChainModal: (open: boolean) => void;
  setBridgePausedModal: (open: boolean) => void;
}

export const modalStore = createStore<ModalState>((set) => ({
  switchChainModal: false,
  bridgePausedModal: false,
  setSwitchChainModal: (switchChainModal) => set({ switchChainModal }),
  setBridgePausedModal: (bridgePausedModal) => set({ bridgePausedModal }),
}));

/** React hook bound to the vanilla modal store. */
export function useModalStore<T>(selector: (state: ModalState) => T): T {
  return useStore(modalStore, selector);
}
