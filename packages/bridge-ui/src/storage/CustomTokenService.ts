import type { Token, TokenService } from '../domain/token';

const STORAGE_PREFIX = 'custom-tokens';

export class CustomTokenService implements TokenService {
  private readonly storage: Storage;

  constructor(storage: Storage) {
    this.storage = storage;
  }

  private _getTokensFromStorage(address: string): Token[] {
    const customTokens = this.storage.getItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
    );

    // TODO: handle invalid JSON
    const tokens: Token[] = customTokens ? JSON.parse(customTokens) : [];

    return tokens;
  }

  storeToken(token: Token, address: string): Token[] {
    const tokens: Token[] = this._getTokensFromStorage(address);

    const doesTokenAlreadyExist =
      tokens.findIndex(
        (tokenFromStorage) => tokenFromStorage.symbol === token.symbol,
      ) >= 0;

    if (!doesTokenAlreadyExist) {
      tokens.push(token);
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
    const tokens: Token[] = this._getTokensFromStorage(address);

    const updatedTokenList = tokens.filter(
      (tokenFromStorage) => tokenFromStorage.symbol !== token.symbol,
    );

    this.storage.setItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
      JSON.stringify(updatedTokenList),
    );

    return updatedTokenList;
  }
}
