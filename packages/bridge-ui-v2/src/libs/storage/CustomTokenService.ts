import { type Address, zeroAddress } from "viem";

import type { Token, TokenService } from "$libs/token";
import { jsonParseWithDefault } from "$libs/util/jsonParseWithDefault";

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
        const existingCustomTokens = this.storage.getItem(
            `${STORAGE_PREFIX}-${address.toLowerCase()}`,
        );

        return jsonParseWithDefault(existingCustomTokens, []);
    }

    storeToken(token: Token, address: string): Token[] {
        const tokens: Token[] = this._getTokensFromStorage(address);

        let doesTokenAlreadyExist = false;
        if (tokens.length > 0) {
            doesTokenAlreadyExist =
                tokens.findIndex(
                    (tokenFromStorage) => tokenFromStorage.symbol === token.symbol,
                ) >= 0;
        }
        if (!doesTokenAlreadyExist) {
            tokens.push(token);
        }

        this.storage.setItem(
            `${STORAGE_PREFIX}-${address.toLowerCase()}`,
            JSON.stringify(tokens),
        );
        this.storageChangeNotifier.dispatchEvent(new CustomEvent('storageChange', { detail: tokens }));


        return tokens;
    }

    getTokens(address: string): Token[] {
        if (address) {
            return this._getTokensFromStorage(address);

        } return [];
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
        this.storageChangeNotifier.dispatchEvent(new CustomEvent('storageChange', { detail: updatedTokenList }));

        return updatedTokenList;
    }

    updateToken(token: Token, address: Address): boolean {
        // const tokens: Token[] = this._getTokensFromStorage(address);
        // const addressesToUpdate = Object.values(token.addresses);

        // const tokenIndex = tokens.findIndex(storedToken =>
        //     addressesToUpdate.some(addressToUpdate =>
        //         addressToUpdate !== zeroAddress &&
        //         Object.values(storedToken.addresses).includes(addressToUpdate)
        //     )
        // );

        // if (tokenIndex !== -1) {
        //     tokens[tokenIndex] = token;
        // } else {
        //     return false
        // }
        const tokens: Token[] = this._getTokensFromStorage(address);
        const addressesToUpdate = Object.values(token.addresses).filter(a => a !== zeroAddress);

        const storedToken = tokens.find(t =>
            addressesToUpdate.some(addressToUpdate => Object.values(t.addresses).includes(addressToUpdate))
        );

        if (!storedToken) return false;

        storedToken.addresses = { ...storedToken.addresses, ...token.addresses };
        this.storage.setItem(
            `${STORAGE_PREFIX}-${address.toLowerCase()}`,
            JSON.stringify(tokens),
        );
        this.storageChangeNotifier.dispatchEvent(new CustomEvent('storageChange', { detail: tokens }));

        return true;
    }

    subscribeToChanges(callback: (tokens: Token[]) => void): void {
        this.storageChangeNotifier.addEventListener('storageChange', (event) => callback((event as CustomEvent).detail));
    }

    unsubscribeFromChanges(callback: (tokens: Token[]) => void): void {
        this.storageChangeNotifier.removeEventListener('storageChange', (event) => callback((event as CustomEvent).detail));
    }
}