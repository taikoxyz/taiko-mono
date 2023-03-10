import type { Token, TokenService } from 'src/domain/token';

interface storage {
  getItem(key: string): string;
  setItem(key: string, value: string);
}

class CustomTokenService implements TokenService {
  private readonly storage: storage;

  constructor(storage: storage) {
    this.storage = storage;
  }

  async StoreToken(token: Token, address: string): Promise<Token[]> {
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

  GetTokens(address: string): Token[] {
    return (
      JSON.parse(
        this.storage.getItem(`custom-tokens-${address.toLowerCase()}`),
      ) ?? []
    );
  }

  RemoveToken(token: Token, address: string): Token[] {
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

export { CustomTokenService };
