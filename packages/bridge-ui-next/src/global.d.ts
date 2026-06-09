// Ambient globals ported from the original SvelteKit app's src/app.d.ts.
// Many ported library files rely on these types ambiently (e.g. Maybe<T>).
declare global {
  type Maybe<T> = T | null | undefined;
  type MaybeArray<T> = T | T[] | null | undefined;
  type MaybePromise<T> = T | Promise<T> | null | undefined;
  type Position =
    | "top"
    | "top-right"
    | "right"
    | "bottom-right"
    | "bottom"
    | "bottom-left"
    | "left"
    | "top-left";
}

// Ambient module declaration ported from the original SvelteKit app's
// src/types.d.ts (the `ethereum-address` package ships no types).
declare module "ethereum-address" {
  export function isAddress(address: string): boolean;
  export function isChecksumAddress(address: string): boolean;
}

export {};
