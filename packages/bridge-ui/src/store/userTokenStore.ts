import type { Token, TokenService } from "src/domain/token";
import { writable } from "svelte/store";

const userTokenStore = writable<TokenService>();
const userTokens = writable<Token[]>([]);
export { userTokenStore, userTokens };
