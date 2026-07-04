import { type Address, zeroAddress } from 'viem';

import type { Token, TokenService } from '$libs/token';
import { jsonParseWithDefault } from '$libs/util/jsonParseWithDefault';
import { getLogger } from '$libs/util/logger';

const STORAGE_PREFIX = 'custom-tokens';

const log = getLogger('storage:CustomTokenService');

export class CustomTokenService implements TokenService {
  private readonly storage: Storage;

  private readonly storageChangeNotifier: EventTarget;

  constructor(storage: Storage) {
    log('CustomTokenService instantiated');
    this.storage = storage;
    this.storageChangeNotifier = new EventTarget();
  }

  private _getTokensFromStorage(address: string): Token[] {
    const storageKey = `${STORAGE_PREFIX}-${address.toLowerCase()}`;
    const existingCustomTokens = this.storage.getItem(storageKey);

    const tokens = jsonParseWithDefault(existingCustomTokens, []);
    log('Retrieved tokens from storage', { address, tokenCount: tokens.length, storageKey });

    return tokens;
  }

  storeToken(token: Token, address: string): Token[] {
    log('Storing token', { tokenSymbol: token.symbol, address });

    const tokens: Token[] = this._getTokensFromStorage(address);

    let doesTokenAlreadyExist = false;
    if (tokens.length > 0) {
      doesTokenAlreadyExist = tokens.findIndex((tokenFromStorage) => tokenFromStorage.symbol === token.symbol) >= 0;
    }

    if (!doesTokenAlreadyExist) {
      log('Adding new token to storage', { tokenSymbol: token.symbol, address });
      token.imported = true;
      tokens.push(token);
    } else {
      log('Token already exists in storage, skipping', { tokenSymbol: token.symbol, address });
    }

    const storageKey = `${STORAGE_PREFIX}-${address.toLowerCase()}`;
    this.storage.setItem(
      storageKey,
      JSON.stringify(tokens, (_, value) => (typeof value === 'bigint' ? Number(value) : value)),
    );
    this.storageChangeNotifier.dispatchEvent(new CustomEvent('storageChange', { detail: tokens }));

    log('Token storage updated', { address, totalTokens: tokens.length, storageKey });
    return tokens;
  }

  getTokens(address: string): Token[] {
    if (address) {
      const tokens = this._getTokensFromStorage(address);
      log('Getting tokens for address', { address, tokenCount: tokens.length });
      return tokens;
    }
    log('No address provided, returning empty array');
    return [];
  }

  removeToken(token: Token, address: string): Token[] {
    log('Removing token', { tokenSymbol: token.symbol, address });

    const tokens: Token[] = this._getTokensFromStorage(address);

    const updatedTokenList = tokens.filter((tokenFromStorage) => tokenFromStorage.symbol !== token.symbol);

    const storageKey = `${STORAGE_PREFIX}-${address.toLowerCase()}`;
    this.storage.setItem(storageKey, JSON.stringify(updatedTokenList));
    this.storageChangeNotifier.dispatchEvent(new CustomEvent('storageChange', { detail: updatedTokenList }));

    log('Token removed from storage', {
      tokenSymbol: token.symbol,
      address,
      previousCount: tokens.length,
      newCount: updatedTokenList.length,
      storageKey,
    });
    return updatedTokenList;
  }

  updateToken(token: Token, address: Address): Token[] {
    log('Updating token', { tokenSymbol: token.symbol, address });

    // Get the tokens from storage
    const tokens: Token[] = this._getTokensFromStorage(address);

    // Filter out zero addresses from the new token's addresses
    const filteredAddresses = Object.fromEntries(
      Object.entries(token.addresses).filter(([, value]) => value !== zeroAddress),
    );

    log('Filtered token addresses', {
      originalAddresses: Object.keys(token.addresses).length,
      filteredAddresses: Object.keys(filteredAddresses).length,
    });

    // Find the stored token to update
    const storedToken = tokens.find((storedToken) =>
      Object.values(filteredAddresses).some((addressToUpdate) =>
        Object.values(storedToken.addresses).includes(addressToUpdate),
      ),
    );

    // If the stored token was found, update its addresses
    if (storedToken) {
      log('Found stored token to update', {
        storedTokenSymbol: storedToken.symbol,
        oldAddresses: Object.keys(storedToken.addresses).length,
      });

      storedToken.addresses = { ...storedToken.addresses, ...filteredAddresses };

      // Save the updated tokens back to storage
      const storageKey = `${STORAGE_PREFIX}-${address.toLowerCase()}`;
      this.storage.setItem(storageKey, JSON.stringify(tokens));
      this.storageChangeNotifier.dispatchEvent(new CustomEvent('storageChange', { detail: tokens }));

      log('Token updated successfully', {
        tokenSymbol: storedToken.symbol,
        newAddresses: Object.keys(storedToken.addresses).length,
        storageKey,
      });
    } else {
      log('No matching stored token found for update', { tokenSymbol: token.symbol, address });
    }

    return tokens;
  }

  subscribeToChanges(callback: (tokens: Token[]) => void): void {
    log('Subscribing to storage changes');
    this.storageChangeNotifier.addEventListener('storageChange', (event) => callback((event as CustomEvent).detail));
  }

  unsubscribeFromChanges(callback: (tokens: Token[]) => void): void {
    log('Unsubscribing from storage changes');
    this.storageChangeNotifier.removeEventListener('storageChange', (event) => callback((event as CustomEvent).detail));
  }
}
