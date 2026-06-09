// Ported verbatim from
// src/components/Dialogs/ClaimDialog/mode.ts.

export type ClaimDialogMode = "claim" | "try_claim";

export function shouldSkipMessageStatusCheck(mode: ClaimDialogMode): boolean {
  return mode === "try_claim";
}
