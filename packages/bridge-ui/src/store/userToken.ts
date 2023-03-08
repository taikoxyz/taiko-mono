import type { Token, TokenService } from 'src/domain/token';
import { writable } from 'svelte/store';

const tokenService = writable<TokenService>();
const userTokens = writable<Token[]>([]);
export { tokenService, userTokens };
