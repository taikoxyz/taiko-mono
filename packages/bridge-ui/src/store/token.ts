import { writable } from 'svelte/store';

import type { Token } from '../domain/token';
import { ETHToken } from '../token/tokens';

export const token = writable<Token>(ETHToken);
