// Ambient module declaration ported verbatim from the original SvelteKit app's
// src/types.d.ts (the `ethereum-address` package ships no types).
//
// This MUST live in a file that is NOT a module (no top-level import/export),
// otherwise the `declare module` is treated as an augmentation rather than an
// ambient declaration. The sibling `global.d.ts` ends with `export {}` (needed
// for its `declare global` block), which is why that copy does not register.
declare module "ethereum-address" {
  export function isAddress(address: string): boolean;
  export function isChecksumAddress(address: string): boolean;
}
