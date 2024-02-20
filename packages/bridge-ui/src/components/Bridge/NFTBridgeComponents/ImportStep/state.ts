import { writable } from 'svelte/store';

import { ImportMethod } from '$components/Bridge/types';

export const selectedImportMethod = writable<ImportMethod>(ImportMethod.NONE);
