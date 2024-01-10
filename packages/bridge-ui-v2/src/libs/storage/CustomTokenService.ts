import { type Address, zeroAddress } from 'viem';

import type { Token, TokenService } from '$libs/token';
import { jsonParseWithDefault } from '$libs/util/jsonParseWithDefault';

const STORAGE_PREFIX = 'custom-tokens';

// Todo: add logging

export class CustomTokenService implements TokenService {
  private readonly storage: Storage;

  private readonly storageChangeNotifier: EventTarget;

  constructor(storage: Storage) {
    this.storage = storage;
    this.storageChangeNotifier = new EventTarget();
  }

  private _getTokensFromStorage(address: string): Token[] {
    const existingCustomTokens = this.storage.getItem(`${STORAGE_PREFIX}-${address.toLowerCase()}`);

    return jsonParseWithDefault(existingCustomTokens, []);
  }

  storeToken(token: Token, address: string): Token[] {
    const tokens: Token[] = this._getTokensFromStorage(address);

    let doesTokenAlreadyExist = false;
    if (tokens.length > 0) {
      doesTokenAlreadyExist = tokens.findIndex((tokenFromStorage) => tokenFromStorage.symbol === token.symbol) >= 0;
    }
    if (!doesTokenAlreadyExist) {
      token.imported = true;
      tokens.push(token);
    }

    this.storage.setItem(
      `${STORAGE_PREFIX}-${address.toLowerCase()}`,
      JSON.stringify(tokens, (_, value) => (typeof value === 'bigint' ? Number(value) : value)),
    );
    this.storageChangeNotifier.dispatchEvent(new CustomEvent('storageChange', { detail: tokens }));

    return tokens;
  }

  getTokens(address: string): Token[] {
    if (address) {
      return this._getTokensFromStorage(address);
    }
    return [];
  }

  removeToken(token: Token, address: string): Token[] {
    const tokens: Token[] = this._getTokensFromStorage(address);

    const updatedTokenList = tokens.filter((tokenFromStorage) => tokenFromStorage.symbol !== token.symbol);

    this.storage.setItem(`${STORAGE_PREFIX}-${address.toLowerCase()}`, JSON.stringify(updatedTokenList));
    this.storageChangeNotifier.dispatchEvent(new CustomEvent('storageChange', { detail: updatedTokenList }));

    return updatedTokenList;
  }

  updateToken(token: Token, address: Address): Token[] {
    // Get the tokens from storage
    const tokens: Token[] = this._getTokensFromStorage(address);

    // Filter out zero addresses from the new token's addresses
    const filteredAddresses = Object.fromEntries(
      Object.entries(token.addresses).filter(([, value]) => value !== zeroAddress),
    );

    // Find the stored token to update
    const storedToken = tokens.find((storedToken) =>
      Object.values(filteredAddresses).some((addressToUpdate) =>
        Object.values(storedToken.addresses).includes(addressToUpdate),
      ),
    );

    // If the stored token was found, update its addresses
    if (storedToken) {
      storedToken.addresses = { ...storedToken.addresses, ...filteredAddresses };

      // Save the updated tokens back to storage
      this.storage.setItem(`${STORAGE_PREFIX}-${address.toLowerCase()}`, JSON.stringify(tokens));
      this.storageChangeNotifier.dispatchEvent(new CustomEvent('storageChange', { detail: tokens }));
    }

    return tokens;
  }

  subscribeToChanges(callback: (tokens: Token[]) => void): void {
    this.storageChangeNotifier.addEventListener('storageChange', (event) => callback((event as CustomEvent).detail));
  }

  unsubscribeFromChanges(callback: (tokens: Token[]) => void): void {
    this.storageChangeNotifier.removeEventListener('storageChange', (event) => callback((event as CustomEvent).detail));
  }
}
