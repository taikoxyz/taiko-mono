import axios from 'axios';
import type { Address } from 'viem';

import { parseApiBigInt, parseRelayerApiResponse, RelayerAPIService } from './RelayerAPIService';

function setupMocks() {
  vi.mock('axios');
  vi.mock('@wagmi/core');
  vi.mock('@web3modal/wagmi');
  vi.mock('$bridgeConfig', () => ({
    routingContractsMap: {
      1: {
        167000: { bridgeAddress: '0xd60247c6848b7ca29eddf63aa924e53db6ddd8ec' },
      },
      167000: {
        1: {
          bridgeAddress: '',
        },
      },
    },
  }));
}

describe('RelayerAPIService', () => {
  beforeEach(() => {
    setupMocks();
  });

  afterEach(() => {
    vi.clearAllMocks();
    vi.resetAllMocks();
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
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(address, paginationParams);

    // Then
    expect(result).toBeDefined();
    expect(result.txs).toBeInstanceOf(Array);
    expect(result.paginationInfo).toBeDefined();
  });

  test('getTransactionsFromAPI preserves raw message fee digits before JSON parsing', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const params = { address: '0x123' as Address, chainID: 1, event: 'MessageSent' };
    const exactFee = 9_007_199_254_740_993n;
    const rawResponse = `{"page":1,"size":10,"total":100,"items":[{"data":{"Message":{"Fee":${exactFee}}}}]}`;
    mockedAxios.get.mockResolvedValue({
      data: rawResponse,
      status: 200,
    });

    // When
    const result = await relayerAPIService.getTransactionsFromAPI(params);

    // Then
    expect(result.items[0].data.Message.Fee).toEqual(exactFee.toString());
  });

  test('parseRelayerApiResponse preserves non-representable message fee digits', () => {
    // Given
    const exactFee = 9_007_199_254_740_993n;
    const rawResponse = `{"items":[{"data":{"Message":{"Fee":${exactFee}}}}]}`;

    // When / Then
    expect(JSON.parse(rawResponse).items[0].data.Message.Fee).toEqual(9_007_199_254_740_992);
    expect(parseRelayerApiResponse(rawResponse).items[0].data.Message.Fee).toEqual(exactFee.toString());
    expect(parseApiBigInt(parseRelayerApiResponse(rawResponse).items[0].data.Message.Fee)).toEqual(exactFee);
  });

  test('parseApiBigInt rejects unsafe numbers that were already rounded', () => {
    expect(() => parseApiBigInt(9_007_199_254_740_992)).toThrow('Unsafe integer value from relayer API');
  });
});
