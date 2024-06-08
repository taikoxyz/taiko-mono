import axios from 'axios';
import type { Address } from 'viem';

import { RelayerAPIService } from './RelayerAPIService';

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
    const chainID = 1;

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
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(address, paginationParams, chainID);

    // Then
    expect(result).toBeDefined();
    expect(result.txs).toBeInstanceOf(Array);
    expect(result.paginationInfo).toBeDefined();
  });

  test('getTransactionsFromAPI should return API response for full mock with valid conversion', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const address = '0x1234567890abcdef1234567890abcdef12345678' as Address;
    const mockResponse = {
      data: {
        items: [
          {
            id: 28652,
            name: 'MessageSent',
            data: {
              Raw: {
                data: '0x00000001302103010',
                topics: ['0x0d6f6f6d'],
                address: '0xd60247c6848b7ca29eddf63aa924e53db6ddd8ec',
                removed: false,
                logIndex: '0xd8',
                blockHash: '0xa2093d50a045b4ed56d21fa705ace1ee9405a8648df990f42ad253431a9087d5',
                blockNumber: '0x13102f0',
                transactionHash: '0x1234567891aca2024a8f058bb2cb636a38e88bc087e682198a42b752319e1241',
                transactionIndex: '0x67',
              },
              Message: {
                Id: 4484,
                To: '0x1234567890abcdef1234567890abcdef12345678',
                Fee: 122994170508407000000,
                Data: '',
                From: '0x1234567890abcdef1234567890abcdef12345678',
                Value: 2994170508407000000,
                GasLimit: 0,
                SrcOwner: '0x1234567890abcdef1234567890abcdef12345678',
                DestOwner: '0x1234567890abcdef1234567890abcdef12345678',
                SrcChainId: 1,
                DestChainId: 167000,
              },
              MsgHash: [201, 18, 253],
            },
            status: 2,
            eventType: 0,
            chainID: 1,
            destChainID: 167000,
            syncedChainID: 0,
            emittedBlockID: 19989232,
            blockID: 0,
            syncedInBlockID: 0,
            syncData: '',
            kind: '',
            canonicalTokenAddress: '',
            canonicalTokenSymbol: '',
            canonicalTokenName: '',
            canonicalTokenDecimals: 0,
            amount: '2994170508407000000',
            msgHash: '0x5f43e7d5a2c3b9e8d10e8f5b4a69c98cb4d5b9e92e4a5f1f6d7b4e5a9c8b7d10',
            messageOwner: '0x1234567890abcdef1234567890abcdef12345678',
            event: 'MessageSent',
          },
        ],
        page: 0,
        size: 100,
        max_page: 0,
        total_pages: 1,
        total: 1,
        last: true,
        first: true,
        visible: 1,
      },
    };

    mockedAxios.get.mockResolvedValue(mockResponse);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(address, { page: 0, size: 100 }, 1);

    // Then
    expect(result).toBeDefined();
    expect(result.txs).toBeInstanceOf(Array);
    expect(result.txs.length).toBe(1);
    expect(result.txs[0].amount).toBe(2994170508407000000n);
    expect(result.txs[0].message?.value).toBe(2994170508407000000n);
    expect(result.txs[0].message?.srcChainId).toBe(1n);
    expect(result.txs[0].message?.destChainId).toBe(167000n);
    expect(result.txs[0].message?.srcOwner).toBe('0x1234567890abcdef1234567890abcdef12345678');
    expect(result.txs[0].message?.destOwner).toBe('0x1234567890abcdef1234567890abcdef12345678');
    expect(result.txs[0].message?.to).toBe('0x1234567890abcdef1234567890abcdef12345678');
    expect(result.txs[0].message?.fee).toBe(122994170508407000000n);
    expect(result.txs[0].message?.gasLimit).toBe(0);
    expect(result.txs[0].message?.data).toBe('0x');
  });
});
