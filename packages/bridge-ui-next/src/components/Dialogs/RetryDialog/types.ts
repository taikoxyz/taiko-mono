// Ported from src/components/Dialogs/RetryDialog/types.ts.
// The original used `export const enum`; under Next.js + `isolatedModules: true`
// a const enum cannot be safely consumed/re-exported across module boundaries
// (its members are erased at emit), so plain `enum`s are used. Numeric member
// values are identical to the source.

export enum RetrySteps {
  CHECK,
  SELECT,
  REVIEW,
  CONFIRM,
}

export const INITIAL_STEP = RetrySteps.CHECK;

export enum RetryStatus {
  PENDING,
  DONE,
}

export enum RETRY_OPTION {
  CONTINUE,
  RETRY_ONCE,
}
