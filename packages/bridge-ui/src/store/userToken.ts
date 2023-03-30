import type { Token, TokenService } from '../domain/token';
import { writable } from 'svelte/store';

const tokenService = writable<TokenService>();
const userTokens = writable<Token[]>([]);
export { tokenService, userTokens };
