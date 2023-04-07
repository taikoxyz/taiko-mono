import type { Token } from '../domain/token';
import { CustomTokenService } from './CustomTokenService';

const mockStorageTokens = [{ symbol: 'ETH' }, { symbol: 'HORSE' }];
const mockLocalStorage = {
  getItem: jest.fn<string, [string]>(),
  setItem: jest.fn<string, [string]>(),
} as unknown as Storage;

const mockETH = { symbol: 'ETH' } as Token;
const mockERC20 = { symbol: 'BLL' } as Token;
const address = '0x123';

beforeEach(() => {
  jest.mocked(mockLocalStorage.getItem).mockImplementation(() => {
    return JSON.stringify(mockStorageTokens);
  });
});

describe('CustomTokenService', () => {
  it('should store token', () => {
    const tokenService = new CustomTokenService(mockLocalStorage);

    const tokens = tokenService.storeToken(mockETH, address);

    // Since ETH is already in the list, it should not be added again
    expect(tokens).toEqual(mockStorageTokens);

    const tokensWithBLL = tokenService.storeToken(mockERC20, address);

    // Since BLL is not in the list, it should be added
    expect(tokensWithBLL).toEqual([...mockStorageTokens, mockERC20]);
  });

  it('should get tokens', () => {
    const tokenService = new CustomTokenService(mockLocalStorage);

    const tokens = tokenService.getTokens(address);

    expect(tokens).toEqual(mockStorageTokens);

    // Let's mock the storage to return null this time
    jest.mocked(mockLocalStorage.getItem).mockImplementation(() => null);

    const tokensEmpty = tokenService.getTokens(address);

    // Should return empty array if no tokens are stored
    expect(tokensEmpty).toEqual([]);
  });

  it('should remove token', () => {
    const tokenService = new CustomTokenService(mockLocalStorage);

    const tokens = tokenService.removeToken(mockETH, address);

    // Since ETH is in the list, it should be removed
    expect(tokens).toEqual([{ symbol: 'HORSE' }]);

    const tokensEmpty = tokenService.removeToken(mockERC20, address);

    // Since BLL is not in the list, it should return the same list
    expect(tokensEmpty).toEqual(mockStorageTokens);
  });

  it('handles invalid JSON', () => {
    jest.mocked(mockLocalStorage.getItem).mockImplementation(() => {
      return 'invalid json';
    });

    const tokenService = new CustomTokenService(mockLocalStorage);

    const tokens = tokenService.getTokens(address);

    expect(tokens).toEqual([]);
  });
});
