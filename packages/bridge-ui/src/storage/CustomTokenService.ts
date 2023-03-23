import type { Token, TokenService } from 'src/domain/token';

export class CustomTokenService implements TokenService {
  private readonly storage: Storage;

  constructor(storage: Storage) {
    this.storage = storage;
  }

  async storeToken(token: Token, address: string): Promise<Token[]> {
    const customTokens = this.storage.getItem(
      `custom-tokens-${address.toLowerCase()}`,
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
      `custom-tokens-${address.toLowerCase()}`,
      JSON.stringify(tokens),
    );
    return tokens;
  }

  getTokens(address: string): Token[] {
    return (
      JSON.parse(
        this.storage.getItem(`custom-tokens-${address.toLowerCase()}`),
      ) ?? []
    );
  }

  removeToken(token: Token, address: string): Token[] {
    const customTokens = this.storage.getItem(
      `custom-tokens-${address.toLowerCase()}`,
    );
    let tokens = [];
    if (customTokens) {
      tokens = [...JSON.parse(customTokens)];
    }
    const updatedTokenList = tokens.filter((t) => t.symbol !== token.symbol);
    this.storage.setItem(
      `custom-tokens-${address.toLowerCase()}`,
      JSON.stringify(updatedTokenList),
    );
    return updatedTokenList;
  }
}
