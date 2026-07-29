import { getTransactionReceipt, readContract } from '@wagmi/core';
import axios from 'axios';
import type { Address, Hash, Hex } from 'viem';

import { parseApiBigInt, parseRelayerApiResponse, RelayerAPIService } from './RelayerAPIService';

const USER_ADDRESS = '0xD23D1e189ecFAb978c8573e7708Ed603cAaa1f47';
const SRC_TX_HASH = '0xc7fbc098585169900af9ea77ac9972a10c128ce0f76abdfadbf3a611ebc1307b';
const GOOD_MSG_HASH = '0x144e93c8e2bb7d5cef8baea0c11a88cd8d1771d63905b4c9574e54ac57756273';
const BAD_MSG_HASH = '0x8165263c4ab44098b8e0a4a44204163ac766a14adb97a9087df98489ba53d110';
const TAIKO_BRIDGE_ADDRESS = '0x1670000000000000000000000000000000000001';

vi.mock('axios');
vi.mock('@wagmi/core', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@wagmi/core')>();
  return {
    ...actual,
    getTransactionReceipt: vi.fn(),
    readContract: vi.fn(),
  };
});
vi.mock('@web3modal/wagmi');
vi.mock('$libs/wagmi', () => ({
  config: {},
}));
vi.mock('$libs/chain', async (importOriginal) => {
  const actual = await importOriginal<typeof import('$libs/chain')>();
  return {
    ...actual,
    isSupportedChain: (chainId: number) => [1, 167000].includes(chainId),
  };
});
vi.mock('$bridgeConfig', () => ({
  routingContractsMap: {
    1: {
      167000: { bridgeAddress: '0xd60247c6848b7ca29eddf63aa924e53db6ddd8ec' },
    },
    167000: {
      1: {
        bridgeAddress: '0x1670000000000000000000000000000000000001',
      },
    },
  },
}));

describe('RelayerAPIService', () => {
  afterEach(() => {
    vi.clearAllMocks();
    vi.resetAllMocks();
  });

  // Given
  const mockedAxios = vi.mocked(axios, true);
  const mockedGetTransactionReceipt = vi.mocked(getTransactionReceipt);
  const mockedReadContract = vi.mocked(readContract);

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

  test('getAllBridgeTransactionByAddress corrects duplicated relayer data from the source receipt log', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    const badRelayerItem = createRelayerItem({
      id: 1553823,
      messageId: '6271',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7ba91a',
    });
    const goodRelayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6268',
      msgHash: GOOD_MSG_HASH,
      blockNumber: '0x7baa21',
    });

    mockedAxios.get.mockResolvedValue({
      data: {
        page: 1,
        size: 10,
        total: 2,
        total_pages: 1,
        max_page: 1,
        first: true,
        last: true,
        visible: 2,
        items: [badRelayerItem, goodRelayerItem],
      },
      status: 200,
    });
    mockedGetTransactionReceipt.mockResolvedValue(createReceiptWithMessageSentLog());
    mockedReadContract.mockResolvedValue(0);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].msgHash).toEqual(GOOD_MSG_HASH);
    expect(result.txs[0].message?.id).toEqual(6268n);
    expect(result.txs[0].message?.gasLimit).toEqual(806657);
    expect(typeof result.txs[0].message?.gasLimit).toEqual('number');
    expect(result.txs[0].blockNumber).toEqual('0x7baa21');
    expect(mockedReadContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        args: [GOOD_MSG_HASH],
      }),
    );
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

function createRelayerItem({
  id,
  messageId,
  msgHash,
  blockNumber,
}: {
  id: number;
  messageId: string;
  msgHash: Hash;
  blockNumber: Hex;
}) {
  return {
    id,
    name: 'MessageSent',
    data: {
      Message: {
        Id: messageId,
        Fee: '467106403297320',
        GasLimit: 806657,
        From: USER_ADDRESS,
        SrcChainId: '167000',
        SrcOwner: USER_ADDRESS,
        DestChainId: '1',
        DestOwner: USER_ADDRESS,
        To: USER_ADDRESS,
        RefundTo: USER_ADDRESS,
        Value: '185000000000000000',
        Data: '0x',
        Memo: '',
      },
      Raw: {
        address: TAIKO_BRIDGE_ADDRESS,
        transactionHash: SRC_TX_HASH,
        transactionIndex: '0x1',
        blockNumber,
      },
    },
    status: 0,
    eventType: 0,
    chainID: 167000,
    canonicalTokenAddress: '0x0000000000000000000000000000000000000000',
    canonicalTokenSymbol: 'ETH',
    canonicalTokenName: 'Ether',
    canonicalTokenDecimals: 18,
    amount: '185000000000000000',
    msgHash,
    messageOwner: USER_ADDRESS,
    event: 'MessageSent',
    claimedBy: '',
    processedTxHash: undefined,
    fee: '0',
    isProfitable: false,
    isProfitableEvaluatedAt: '',
  };
}

function createReceiptWithMessageSentLog(): Awaited<ReturnType<typeof getTransactionReceipt>> {
  return {
    status: 'success',
    cumulativeGasUsed: 210721n,
    logs: [
      {
        address: TAIKO_BRIDGE_ADDRESS,
        blockHash: '0xb88411608e875be7e5f9cdcde5f80d749e6c23c27ffa2ab5c598c760050c02a2',
        blockNumber: 8104481n,
        logIndex: 1,
        transactionHash: SRC_TX_HASH,
        transactionIndex: 1,
        removed: false,
        topics: ['0xe33fd33b4f45b95b1c196242240c5b5233129d724b578f95b66ce8d8aae93517', GOOD_MSG_HASH],
        data: '0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000187c0000000000000000000000000000000000000000000000000001a8d4af3da82800000000000000000000000000000000000000000000000000000000000c4f01000000000000000000000000d23d1e189ecfab978c8573e7708ed603caaa1f470000000000000000000000000000000000000000000000000000000000028c58000000000000000000000000d23d1e189ecfab978c8573e7708ed603caaa1f470000000000000000000000000000000000000000000000000000000000000001000000000000000000000000d23d1e189ecfab978c8573e7708ed603caaa1f47000000000000000000000000d23d1e189ecfab978c8573e7708ed603caaa1f47000000000000000000000000000000000000000000000000029140851372800000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000',
      },
    ],
    logsBloom: '0x0',
    type: 'eip1559',
    transactionHash: SRC_TX_HASH,
    transactionIndex: 1,
    blockHash: '0xb88411608e875be7e5f9cdcde5f80d749e6c23c27ffa2ab5c598c760050c02a2',
    blockNumber: 8104481n,
    gasUsed: 98653n,
    effectiveGasPrice: 110000000n,
    from: USER_ADDRESS,
    to: TAIKO_BRIDGE_ADDRESS,
    contractAddress: null,
    chainId: 167000,
  } as unknown as Awaited<ReturnType<typeof getTransactionReceipt>>;
}
