// Ported from src/components/Dialogs/ReleaseDialog/types.ts.
// The original used `export const enum`; under Next.js + `isolatedModules: true`
// a const enum cannot be safely consumed/re-exported across module boundaries
// (its members are erased at emit), so a plain `enum` is used. The numeric
// member values (CHECK=0, REVIEW=1, CONFIRM=2) are identical.

export enum ReleaseSteps {
  CHECK,
  REVIEW,
  CONFIRM,
}

export const INITIAL_STEP = ReleaseSteps.CHECK;
