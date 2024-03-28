import { writable } from 'svelte/store';

import { RETRY_OPTION } from './types';

export const selectedRetryMethod = writable<RETRY_OPTION>(RETRY_OPTION.CONTINUE);
