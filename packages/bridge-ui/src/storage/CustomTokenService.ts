import type { Token, TokenService } from '../domain/token';

const STORAGE_PREFIX = 'custom-tokens';

export class CustomTokenService implements TokenService {
  private readonly storage: Storage;

  constructor(storage: Storage) {
    this.storage = storage;
  }

  storeToken(token: Token, address: string): Token[] {
    const customTokens = this.storage.getItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
    );
    let tokens = [];
    if (customTokens) {
      tokens = [...JSON.parse(customTokens)];
    }
    const doesTokenAlreadyExist = tokens.findIndex(
      (t) => t.symbol === token.symbol,
    );
    if (doesTokenAlreadyExist < 0) {
      tokens.push({ ...token });
    }
    this.storage.setItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
      JSON.stringify(tokens),
    );
    return tokens;
  }

  getTokens(address: string): Token[] {
    return (
      JSON.parse(
        this.storage.getItem(`${STORAGE_PREFIX}-${address.toLowerCase()}`),
      ) ?? []
    );
  }

  removeToken(token: Token, address: string): Token[] {
    const customTokens = this.storage.getItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
    );
    let tokens = [];
    if (customTokens) {
      tokens = [...JSON.parse(customTokens)];
    }
    const updatedTokenList = tokens.filter((t) => t.symbol !== token.symbol);
    this.storage.setItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
      JSON.stringify(updatedTokenList),
    );
    return updatedTokenList;
  }
}
