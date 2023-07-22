import type { Chain } from '@wagmi/core';
import { writable } from 'svelte/store';

import type { Token } from '$libs/token';

// Note: we could combine this with Context API, but since we'll only
// have one Bridge component, it would be an overkill. If we wanted to
// instantiate multiple Bridge components, then we'd need to use
// Context API to avoid having multiple instances of the same store.
// One could argue that we only want this store to be used by the Bridge
// and its descendants, in which case Context API would be the one to use,
// but once again, we don't need such level of security that we have to
// prevent other components outside the Bridge from accessing this store.

export const selectedToken = writable<Maybe<Token>>(null);
export const enteredAmount = writable<bigint>(BigInt(0));
export const destNetwork = writable<Maybe<Chain>>(null);
export const processingFee = writable<bigint>(BigInt(0));
