import type { Token, TokenService } from '../domain/token';
import { jsonParseOrEmptyArray } from '../utils/jsonParseOrEmptyArray';

const STORAGE_PREFIX = 'custom-tokens';

export class CustomTokenService implements TokenService {
  private readonly storage: Storage;

  constructor(storage: Storage) {
    this.storage = storage;
  }

  private _getTokensFromStorage(address: string): Token[] {
    const existingCustomTokens = this.storage.getItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
    );

    return jsonParseOrEmptyArray<Token>(existingCustomTokens);
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
    return this._getTokensFromStorage(address);
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
