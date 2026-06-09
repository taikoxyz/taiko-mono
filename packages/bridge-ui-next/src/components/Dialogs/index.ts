// Barrel for the Dialogs unit.
// Mirrors the original `src/components/Dialogs/index.ts`, which re-exported the
// three top-level dialog components (each pointed directly at its `.svelte`
// file). The React ports keep the same default-export shape, so they are
// re-exported here verbatim.
export { default as ClaimDialog } from "./ClaimDialog/ClaimDialog";
export { default as ReleaseDialog } from "./ReleaseDialog/ReleaseDialog";
export { default as RetryDialog } from "./RetryDialog/RetryDialog";

// `Claim` is a renderless sibling unit in this folder (Claim.svelte). It was not
// part of the original barrel, but it is the in-scope component for this unit, so
// it is exported here for convenience (the migrated ClaimDialog/RetryDialog/
// ReleaseDialog import it directly from '@/components/Dialogs/Claim').
export { default as Claim } from "./Claim";
export type {
  ClaimHandle,
  ClaimProps,
  ClaimErrorDetail,
  ClaimTxSentDetail,
} from "./Claim";
