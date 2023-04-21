import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { Token } from '../Token/types'
import { CustomTokenStorage } from './CustomTokenStorage'

const mockStorageTokens = [{ symbol: 'ETH' }, { symbol: 'HORSE' }]

const mockStorage = {
  getItem: vi.fn(),
  setItem: vi.fn(),
}

const mockETH = { symbol: 'ETH' } as Token
const mockERC20 = { symbol: 'BLL' } as Token
const address = '0x123'

describe('CustomTokenService', () => {
  beforeEach(() => {
    mockStorage.getItem.mockReturnValue(JSON.stringify(mockStorageTokens))
  })

  it('should store token', () => {
    const tokenService = new CustomTokenStorage(mockStorage as any)

    const tokens = tokenService.storeToken(mockETH, address)

    // Since ETH is already in the list, it should not be added again
    expect(tokens).toEqual(mockStorageTokens)

    const tokensWithBLL = tokenService.storeToken(mockERC20, address)

    // Since BLL is not in the list, it should be added
    expect(tokensWithBLL).toEqual([...mockStorageTokens, mockERC20])
  })

  it('should get tokens', () => {
    const tokenService = new CustomTokenStorage(mockStorage as any)

    const tokens = tokenService.getTokens(address)

    expect(tokens).toEqual(mockStorageTokens)

    // Let's mock the storage to return null this time
    mockStorage.getItem.mockReturnValue(null)

    const tokensEmpty = tokenService.getTokens(address)

    // Should return empty array if no tokens are stored
    expect(tokensEmpty).toEqual([])
  })

  it('should remove token', () => {
    const tokenService = new CustomTokenStorage(mockStorage as any)

    const tokens = tokenService.removeToken(mockETH, address)

    // Since ETH is in the list, it should be removed
    expect(tokens).toEqual([{ symbol: 'HORSE' }])

    const tokensEmpty = tokenService.removeToken(mockERC20, address)

    // Since BLL is not in the list, it should return the same list
    expect(tokensEmpty).toEqual(mockStorageTokens)
  })

  it('handles invalid JSON', () => {
    mockStorage.getItem.mockReturnValue('invalid json')

    const tokenService = new CustomTokenStorage(mockStorage as any)

    const tokens = tokenService.getTokens(address)

    expect(tokens).toEqual([])
  })
})
