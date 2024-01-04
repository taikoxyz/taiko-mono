import axios from 'axios';
import type { Address } from 'viem';

import { RelayerAPIService } from './RelayerAPIService';

function setupMocks() {
  vi.mock('axios');
  vi.mock('@wagmi/core');
  vi.mock('@web3modal/wagmi');
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

describe('RelayerAPIService', () => {
  beforeEach(() => {
    setupMocks();
  });

  // Given
  const mockedAxios = vi.mocked(axios, true);

  test('getTransactionsFromAPI should return API response', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const params = { address: '0x123' as Address, chainID: 1, event: 'MessageSent' };
    const mockResponse = {
      data: {
        page: 1,
        size: 10,
        total: 100,
        items: [],
      },
      status: 200,
    };
    mockedAxios.get.mockResolvedValue(mockResponse);

    // When
    const result = await relayerAPIService.getTransactionsFromAPI(params);

    // Then
    expect(result).toEqual(mockResponse.data);
  });

  test('getAllBridgeTransactionByAddress should return filtered transactions', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const address = '0x123';
    const paginationParams = { page: 1, size: 10 };
    const chainID = 1;

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(address, paginationParams, chainID);

    // Then
    expect(result).toBeDefined();
    expect(result.txs).toBeInstanceOf(Array);
    expect(result.paginationInfo).toBeDefined();
  });
});
