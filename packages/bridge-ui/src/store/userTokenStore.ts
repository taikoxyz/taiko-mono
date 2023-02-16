import type { Token, TokenStore } from "src/domain/token";
import { writable } from "svelte/store";

const userTokenStore = writable<TokenStore>();
const userTokens = writable<Token[]>([]);
export { userTokenStore, userTokens };
