// Ported from src/components/Dialogs/Shared/types.ts.
// The original used `export const enum`; under Next.js + `isolatedModules: true`
// a const enum cannot be safely consumed/re-exported across module boundaries
// (its members are erased at emit), so a plain `enum` is used. The numeric
// member values (CLAIM=0, RETRY=1, RELEASE=2) are identical.

export enum ClaimAction {
  CLAIM,
  RETRY,
  RELEASE,
}
