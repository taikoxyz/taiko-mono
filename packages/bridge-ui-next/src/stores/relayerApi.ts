// Ported from stores/relayerApi.ts.
//
// `paginationInfo` and `relayerBlockInfoMap` have ZERO importers in the original
// codebase (flagged as dead code in the migration plan). They are ported 1:1 for
// parity as Zustand VANILLA stores so any imperative `.setState()` / `.getState()`
// access mirrors svelte's writable contract. If relayer pagination/block info is
// ever needed it should move to TanStack React Query alongside RelayerAPIService.
import { createValueStore } from "@/stores/createValueStore";

import type { PaginationInfo, RelayerBlockInfo } from "$libs/relayer/types";

export const paginationInfo = createValueStore<PaginationInfo | undefined>(
  () => undefined,
);

export const relayerBlockInfoMap = createValueStore<
  Map<number, RelayerBlockInfo> | undefined
>(() => undefined);
