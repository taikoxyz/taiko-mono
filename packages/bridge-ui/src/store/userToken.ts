import type { Token, TokenService } from "src/domain/token";
import { CustomTokenService } from "../storage/customTokenService";
import { writable } from "svelte/store";

const tokenService = writable<TokenService>();
const userTokens = writable<Token[]>([]);

export { tokenService, userTokens };

export function setTokenService(localStorage: Storage) {
    const tokenStore: TokenService = new CustomTokenService(localStorage);

    tokenService.set(tokenStore);

    return tokenService
}
