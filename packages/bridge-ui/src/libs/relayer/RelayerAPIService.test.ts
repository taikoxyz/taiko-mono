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

  test('parseRelayerApiResponse preserves non-representable message integer digits', () => {
    // Given
    const exactFee = 9_007_199_254_740_993n;
    const exactValue = 33_011_093_383_701_312n;
    const rawResponse = `{"items":[{"data":{"Message":{"Fee":${exactFee},"Value":${exactValue},"Id":42,"SrcChainId":1,"DestChainId":167000}}}]}`;

    // When / Then
    expect(JSON.parse(rawResponse).items[0].data.Message.Fee).toEqual(9_007_199_254_740_992);
    expect(JSON.parse(rawResponse).items[0].data.Message.Value).toEqual(33_011_093_383_701_310);
    expect(parseRelayerApiResponse(rawResponse).items[0].data.Message.Fee).toEqual(exactFee.toString());
    expect(parseApiBigInt(parseRelayerApiResponse(rawResponse).items[0].data.Message.Fee)).toEqual(exactFee);
    expect(parseRelayerApiResponse(rawResponse).items[0].data.Message.Value).toEqual(exactValue.toString());
    expect(parseApiBigInt(parseRelayerApiResponse(rawResponse).items[0].data.Message.Value)).toEqual(exactValue);
    expect(parseApiBigInt(parseRelayerApiResponse(rawResponse).items[0].data.Message.Id)).toEqual(42n);
    expect(parseApiBigInt(parseRelayerApiResponse(rawResponse).items[0].data.Message.SrcChainId)).toEqual(1n);
    expect(parseApiBigInt(parseRelayerApiResponse(rawResponse).items[0].data.Message.DestChainId)).toEqual(167000n);
  });

  test('parseRelayerApiResponse ignores escaped Fee-like text inside string values', () => {
    // Given
    const exactFee = 9_007_199_254_740_993n;
    const rawResponse = `{"items":[{"data":{"Message":{"Fee":${exactFee},"Memo":"quoted \\"Fee\\":9007199254740993 text"}}}]}`;

    // When
    const result = parseRelayerApiResponse(rawResponse);

    // Then
    expect(result.items[0].data.Message.Fee).toEqual(exactFee.toString());
    expect(result.items[0].data.Message.Memo).toEqual('quoted "Fee":9007199254740993 text');
  });

  test('parseApiBigInt rejects unsafe numbers that were already rounded', () => {
    expect(() => parseApiBigInt(9_007_199_254_740_992)).toThrow('Unsafe integer value from relayer API');
  });

  test('parseApiBigInt preserves exact string input that Number.toString would shorten', () => {
    expect(Number(33_011_093_383_701_312n).toString()).toEqual('33011093383701310');
    expect(parseApiBigInt('33011093383701312')).toEqual(33_011_093_383_701_312n);
  });
});
