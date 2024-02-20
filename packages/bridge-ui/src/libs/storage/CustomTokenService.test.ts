import { type Address, zeroAddress } from 'viem';
import { describe, expect, vi } from 'vitest';

import { type Token, TokenType } from '$libs/token';

import { CustomTokenService } from './CustomTokenService';

const STORAGE_PREFIX = 'custom-tokens';

vi.mock('@wagmi/core');

function setupMocks() {
  vi.mock('$customToken', () => {
    return {
      customToken: [
        {
          name: 'Bull Token',
          addresses: {
            '31336': '0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0',
            '167002': '0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE',
          },
          symbol: 'BLL',
          decimals: 18,
          type: 'ERC20',
          logoURI: 'ipfs://QmezMTpT6ovJ3szb3SKDM9GVGeQ1R8DfjYyXG12ppMe2BY',
          mintable: true,
        },
        {
          name: 'Horse Token',
          addresses: {
            '31336': '0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e',
            '167002': '0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1',
          },
          symbol: 'HORSE',
          decimals: 18,
          type: 'ERC20',
          logoURI: 'ipfs://QmU52ZxmSiGX24uDPNUGG3URyZr5aQdLpACCiD6tap4Mgc',
          mintable: true,
        },
      ],
    };
  });
}

describe('CustomTokenService', () => {
  const localStorage = global.localStorage;
  let token1: Token;
  let token2: Token;
  let address: Address;
  let tokenService: CustomTokenService;
  let storageKey: string;

  const getItemSpy = vi.spyOn(Storage.prototype, 'getItem');
  const setItemSpy = vi.spyOn(Storage.prototype, 'setItem');
  const removeItemSpy = vi.spyOn(Storage.prototype, 'removeItem');

  beforeEach(() => {
    setupMocks();

    tokenService = new CustomTokenService(localStorage);
    address = '0x1234';
    storageKey = STORAGE_PREFIX + '-' + address;

    token1 = {
      name: 'Imported Token',
      addresses: { address1: '0x999', address2: '0x111' },
      symbol: 'TST',
      decimals: 18,
      type: TokenType.ERC20,
      imported: true,
    };
    token2 = {
      name: 'Another Token',
      addresses: { address1: '0x888', address2: zeroAddress },
      symbol: 'T2T',
      decimals: 18,
      type: TokenType.ERC20,
      imported: true,
    };
  });

  afterEach(() => {
    localStorage.clear();

    getItemSpy.mockClear();
    setItemSpy.mockClear();
    removeItemSpy.mockClear();
  });

  test('stores token correctly', () => {
    // When
    const actual = tokenService.storeToken(token1, address);

    // Then
    expect(actual).toStrictEqual([token1]);
    expect(getItemSpy).toHaveBeenCalledWith(storageKey);
  });

  test('returns all stored tokens', () => {
    // Given
    const expected = JSON.stringify([token1, token2]);
    localStorage.setItem(storageKey, expected);

    // When
    const actual = tokenService.getTokens(address);

    // Then
    expect(actual).toStrictEqual([token1, token2]);
    expect(setItemSpy).toHaveBeenCalledWith(storageKey, expected);
  });

  test('removes token correctly', () => {
    // Given
    localStorage.setItem(storageKey, JSON.stringify([token1, token2]));

    // When
    const actual = tokenService.removeToken(token1, address);

    // Then
    expect(actual).toStrictEqual([token2]);
  });

  test('updates token correctly when an address is zeroAddress', () => {
    // Given
    const token2Updated: Token = {
      name: 'Another Token',
      addresses: { address1: '0x888', address2: '0x777' },
      symbol: 'T2T',
      decimals: 18,
      type: TokenType.ERC20,
      imported: true,
    };
    localStorage.setItem(storageKey, JSON.stringify([token1, token2]));

    // When
    const actual = tokenService.updateToken(token2Updated, address);

    // Then
    expect(actual).toStrictEqual([token1, token2Updated]);
  });

  test('updates token correctly when an address is not zeroAddress', () => {
    // Given
    const token1Updated: Token = {
      ...token1,
      addresses: { address1: '0x999', address2: '0x777' },
    };
    localStorage.setItem(storageKey, JSON.stringify([token1, token2]));

    // When
    const actual = tokenService.updateToken(token1Updated, address);

    // Then
    expect(actual).toStrictEqual([token1Updated, token2]);
  });

  test('does not update a non zeroAddress address to zeroAddress', () => {
    // Given
    const token1Updated: Token = {
      ...token1,
      addresses: { address1: '0x999', address2: zeroAddress },
    };
    localStorage.setItem(storageKey, JSON.stringify([token1, token2]));

    // When
    const actual = tokenService.updateToken(token1Updated, address);

    // Then
    expect(actual).toStrictEqual([token1, token2]);
  });
});
