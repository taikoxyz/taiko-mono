// Ported from stores/relayerApi.ts.
//
// `paginationInfo` and `relayerBlockInfoMap` have ZERO importers in the original
// codebase (flagged as dead code in the migration plan). They are ported 1:1 for
// parity as Zustand VANILLA stores so any imperative `.setState()` / `.getState()`
// access mirrors svelte's writable contract. If relayer pagination/block info is
// ever needed it should move to TanStack React Query alongside RelayerAPIService.
import { createStore } from "zustand/vanilla";

import type { PaginationInfo, RelayerBlockInfo } from "$libs/relayer/types";

export const paginationInfo = createStore<PaginationInfo | undefined>(
  () => undefined,
);

export const relayerBlockInfoMap = createStore<
  Map<number, RelayerBlockInfo> | undefined
>(() => undefined);
