import { writable } from 'svelte/store';
import { ETHToken } from '../token/tokens';
import type { Token } from '../domain/token';

export const token = writable<Token>(ETHToken);
