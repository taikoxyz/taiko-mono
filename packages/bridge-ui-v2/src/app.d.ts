// See https://kit.svelte.dev/docs/types#app
// for information about these interfaces
declare global {
  namespace App {
    // interface Error {}
    // interface Locals {}
    // interface PageData {}
    // interface Platform {}
  }

  type Maybe<T> = T | null | undefined;
  type MaybeArray<T> = T | T[] | null | undefined;
  type MaybePromise<T> = T | Promise<T> | null | undefined;
  type Position = 'top' | 'top-right' | 'right' | 'bottom-right' | 'bottom' | 'bottom-left' | 'left' | 'top-left';
}

export {};
