"use client";

// Ported from src/components/Transactions/state.ts.
//
// The original module exposed a single `writable<BridgeTransaction[]>` named
// `transactionStore`. It has ZERO importers in the source app (dead code), but is
// ported verbatim for path parity, following the same VANILLA zustand convention
// used by `$components/Bridge/state.ts`:
//   get(transactionStore)            -> transactionStore.getState()
//   transactionStore.set(v)          -> transactionStore.setState(v)
//   $transactionStore (component)    -> useStore(transactionStore)
import { createStore } from "zustand/vanilla";

import type { BridgeTransaction } from "@/libs/bridge";

export const transactionStore = createStore<BridgeTransaction[]>(() => []);
