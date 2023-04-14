import type { Token } from '../domain/token';
import { writable } from 'svelte/store';

export const userTokens = writable<Token[]>([]);
