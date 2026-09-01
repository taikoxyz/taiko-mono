import { getTransactionReceipt, readContract } from '@wagmi/core';
import axios from 'axios';
import { type Address, encodeAbiParameters, encodeFunctionData, type Hash, type Hex } from 'viem';

import { erc20VaultAbi, erc721VaultAbi, erc1155VaultAbi } from '$abi';
import { MessageStatus } from '$libs/bridge';
import { TokenType } from '$libs/token';

import { parseApiBigInt, parseRelayerApiResponse, RelayerAPIService } from './RelayerAPIService';

const USER_ADDRESS = '0xD23D1e189ecFAb978c8573e7708Ed603cAaa1f47';
const SRC_TX_HASH = '0xc7fbc098585169900af9ea77ac9972a10c128ce0f76abdfadbf3a611ebc1307b';
const SECOND_SRC_TX_HASH = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const GOOD_MSG_HASH = '0x144e93c8e2bb7d5cef8baea0c11a88cd8d1771d63905b4c9574e54ac57756273';
const BAD_MSG_HASH = '0x8165263c4ab44098b8e0a4a44204163ac766a14adb97a9087df98489ba53d110';
const OTHER_MSG_HASH = '0x2b7a9133f2e79adbd61f1f4e7a100cc2fb91d77db708da22e95b5cbb9f6a3111';
const TAIKO_BRIDGE_ADDRESS = '0x1670000000000000000000000000000000000001';
const DEST_CHAIN_TWO_BRIDGE_ADDRESS = '0x2000000000000000000000000000000000000002';
const DEST_ERC20_VAULT_ADDRESS = '0x1000000000000000000000000000000000000020';
const DEST_ERC721_VAULT_ADDRESS = '0x1000000000000000000000000000000000000721';
const DEST_ERC1155_VAULT_ADDRESS = '0x1000000000000000000000000000000000001155';
const CANONICAL_ERC20_ADDRESS = '0x00000000000000000000000000000000000000C1';
const CANONICAL_ERC721_ADDRESS = '0x0000000000000000000000000000000000000721';
const CANONICAL_ERC1155_ADDRESS = '0x0000000000000000000000000000000000001155';
const MESSAGE_SENT_EVENT_TOPIC = '0xe33fd33b4f45b95b1c196242240c5b5233129d724b578f95b66ce8d8aae93517';

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
    isSupportedChain: (chainId: number) => [1, 2, 167000].includes(chainId),
  };
});
vi.mock('$bridgeConfig', () => ({
  routingContractsMap: {
    1: {
      167000: {
        bridgeAddress: '0xd60247c6848b7ca29eddf63aa924e53db6ddd8ec',
        erc20VaultAddress: '0x1000000000000000000000000000000000000020',
        erc721VaultAddress: '0x1000000000000000000000000000000000000721',
        erc1155VaultAddress: '0x1000000000000000000000000000000000001155',
      },
    },
    2: {
      167000: { bridgeAddress: '0x2000000000000000000000000000000000000002' },
    },
    167000: {
      1: {
        bridgeAddress: '0x1670000000000000000000000000000000000001',
      },
      2: {
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
      fee: '1',
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
    mockedGetTransactionReceipt.mockResolvedValue(createReceiptWithMessageSentLog({ fee: 0n }));
    mockedReadContract.mockResolvedValue(0);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].msgHash).toEqual(GOOD_MSG_HASH);
    expect(result.txs[0].message?.id).toEqual(6268n);
    expect(result.txs[0].message?.gasLimit).toEqual(806657);
    expect(typeof result.txs[0].message?.gasLimit).toEqual('number');
    expect(result.txs[0].processingFee).toEqual(0n);
    expect(result.txs[0].blockNumber).toEqual('0x7baa21');
    expect(mockedReadContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        args: [GOOD_MSG_HASH],
      }),
    );
  });

  test('keeps both messages when one transaction emitted two of them', async () => {
    // One source transaction, two MessageSent logs: two separately claimable rows. The
    // duplicate filter used to key on the transaction hash and drop the second outright,
    // before anything downstream could tell it apart from a repeated row
    const relayerAPIService = new RelayerAPIService('http://example.com');
    const first = createRelayerItem({ id: 1, messageId: '6268', msgHash: GOOD_MSG_HASH, blockNumber: '0x7baa21' });
    const second = createRelayerItem({ id: 2, messageId: '6269', msgHash: BAD_MSG_HASH, blockNumber: '0x7baa21' });

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
        items: [first, second],
      },
      status: 200,
    });
    // The receipt proves both: each row matches a log of its own
    mockedGetTransactionReceipt.mockResolvedValue(
      createReceiptWithMessageSentLogs([
        { msgHash: GOOD_MSG_HASH, id: 6268n, logIndex: 1 },
        { msgHash: BAD_MSG_HASH, id: 6269n, logIndex: 2 },
      ]),
    );
    mockedReadContract.mockResolvedValue(0);

    const result = await relayerAPIService.getAllBridgeTransactionByAddress(
      USER_ADDRESS,
      { page: 1, size: 10 },
      167000,
    );

    expect(result.txs).toHaveLength(2);
    expect(result.txs.map((tx) => tx.msgHash).sort()).toEqual([GOOD_MSG_HASH, BAD_MSG_HASH].sort());
    // ...and they still describe one transaction
    expect(new Set(result.txs.map((tx) => tx.srcTxHash)).size).toBe(1);
  });

  test('getAllBridgeTransactionByAddress syncs canonical status to the relayer status field', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6268',
      msgHash: GOOD_MSG_HASH,
      blockNumber: '0x7baa21',
      status: MessageStatus.DONE,
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(createReceiptWithMessageSentLog());
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].msgStatus).toEqual(MessageStatus.NEW);
    expect(result.txs[0].status).toEqual(MessageStatus.NEW);
  });

  test('getAllBridgeTransactionByAddress routes status lookup using receipt message chain IDs', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6268',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7baa21',
      destChainId: '1',
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(
      createReceiptWithMessageSentLog({
        msgHash: GOOD_MSG_HASH,
        destChainId: 2n,
      }),
    );
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].srcChainId).toEqual(167000n);
    expect(result.txs[0].destChainId).toEqual(2n);
    expect(result.txs[0].message?.destChainId).toEqual(2n);
    expect(mockedReadContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        address: DEST_CHAIN_TWO_BRIDGE_ADDRESS,
        chainId: 2,
        args: [GOOD_MSG_HASH],
      }),
    );
  });

  test('getAllBridgeTransactionByAddress keeps an exact msgHash match when receipt has multiple user messages', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    // The row carries the right msgHash but a body copied from the other log, so the returned id can only
    // be 6268 if the receipt was decoded — and only the msgHash can pick the right log, since the row's id
    // points at OTHER_MSG_HASH.
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '9999',
      msgHash: GOOD_MSG_HASH,
      blockNumber: '0x7baa21',
      amount: '999',
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(
      createReceiptWithMessageSentLogs([
        { msgHash: OTHER_MSG_HASH, id: 9999n, logIndex: 1 },
        { msgHash: GOOD_MSG_HASH, id: 6268n, logIndex: 2 },
      ]),
    );
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].msgHash).toEqual(GOOD_MSG_HASH);
    expect(result.txs[0].message?.id).toEqual(6268n);
    expect(result.txs[0].amount).toEqual(185_000_000_000_000_000n);
    expect(mockedReadContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        args: [GOOD_MSG_HASH],
      }),
    );
  });

  test('getAllBridgeTransactionByAddress recovers a missing relayer msgHash from a sole receipt message', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6268',
      msgHash: GOOD_MSG_HASH,
      blockNumber: '0x7baa21',
    });
    relayerItem.msgHash = undefined as unknown as Hash;

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(createReceiptWithMessageSentLog());
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].msgHash).toEqual(GOOD_MSG_HASH);
    expect(mockedReadContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        args: [GOOD_MSG_HASH],
      }),
    );
  });

  test('getAllBridgeTransactionByAddress excludes an unsupported canonical route without dropping valid records', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    const unsupportedRelayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6268',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7baa21',
    });
    const validRelayerItem = createRelayerItem({
      id: 1553883,
      messageId: '6269',
      msgHash: GOOD_MSG_HASH,
      blockNumber: '0x7baa22',
      srcTxHash: SECOND_SRC_TX_HASH,
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([unsupportedRelayerItem, validRelayerItem]));
    mockedGetTransactionReceipt
      .mockResolvedValueOnce(createReceiptWithMessageSentLog({ msgHash: OTHER_MSG_HASH, destChainId: 999n }))
      .mockResolvedValueOnce(createReceiptWithMessageSentLog());
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].srcTxHash).toEqual(SECOND_SRC_TX_HASH);
    expect(mockedReadContract).toHaveBeenCalledTimes(1);
  });

  test('getAllBridgeTransactionByAddress skips a relayer row declaring an unconfigured route', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    // No routingContractsMap entry exists for 167000 -> 424242. Indexing it must not throw, because a single
    // unknown route would otherwise reject the whole request and wipe every relayer transaction.
    const unconfiguredRelayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6268',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7baa21',
      destChainId: '424242',
    });
    const validRelayerItem = createRelayerItem({
      id: 1553883,
      messageId: '6269',
      msgHash: GOOD_MSG_HASH,
      blockNumber: '0x7baa22',
      srcTxHash: SECOND_SRC_TX_HASH,
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([unconfiguredRelayerItem, validRelayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(createReceiptWithMessageSentLog());
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].srcTxHash).toEqual(SECOND_SRC_TX_HASH);
  });

  test('getAllBridgeTransactionByAddress does not let an invalid duplicate hide a valid row', async () => {
    // Given
    const relayerAPIService = new RelayerAPIService('http://example.com');
    const paginationParams = { page: 1, size: 10 };
    const unconfiguredRelayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6268',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7baa21',
      destChainId: '424242',
    });
    const validRelayerItem = createRelayerItem({
      id: 1553883,
      messageId: '6268',
      msgHash: GOOD_MSG_HASH,
      blockNumber: '0x7baa22',
      // Both API rows point at the same source transaction. The invalid row must not consume this hash.
      srcTxHash: SRC_TX_HASH,
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([unconfiguredRelayerItem, validRelayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(createReceiptWithMessageSentLog());
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].msgHash).toEqual(GOOD_MSG_HASH);
  });

  test('getAllBridgeTransactionByAddress clears claim metadata inherited from the mismatched relayer row', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    // claimedBy/processedTxHash/fee/amount all describe the message BAD_MSG_HASH belongs to, not the one
    // this transaction actually sent.
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6271',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7ba91a',
      claimedBy: '0x00000000000000000000000000000000000000dE',
      processedTxHash: OTHER_MSG_HASH,
      relayerFee: '12345',
      amount: '999',
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(createReceiptWithMessageSentLog());
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].msgHash).toEqual(GOOD_MSG_HASH);
    expect(result.txs[0].claimedBy).toBeUndefined();
    expect(result.txs[0].destTxHash).toBeUndefined();
    expect(result.txs[0].fee).toBeUndefined();
    // ETH transfers carry their amount on the message, so it can be corrected from the receipt.
    expect(result.txs[0].amount).toEqual(185_000_000_000_000_000n);
  });

  test('getAllBridgeTransactionByAddress preserves claim metadata for case-equivalent msgHashes', async () => {
    // Given
    const relayerAPIService = new RelayerAPIService('http://example.com');
    const paginationParams = { page: 1, size: 10 };
    const uppercaseMsgHash = `0x${GOOD_MSG_HASH.slice(2).toUpperCase()}` as Hash;
    const claimedBy = '0x00000000000000000000000000000000000000DE';
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6268',
      msgHash: uppercaseMsgHash,
      blockNumber: '0x7baa21',
      claimedBy,
      processedTxHash: OTHER_MSG_HASH,
      relayerFee: '12345',
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(createReceiptWithMessageSentLog());
    mockedReadContract.mockResolvedValue(MessageStatus.DONE);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0]).toEqual(
      expect.objectContaining({
        claimedBy,
        destTxHash: OTHER_MSG_HASH,
        fee: 12_345n,
        msgHash: GOOD_MSG_HASH,
      }),
    );
  });

  test('getAllBridgeTransactionByAddress refreshes ERC20 metadata from the receipt message', async () => {
    // Given
    const relayerAPIService = new RelayerAPIService('http://example.com');
    const paginationParams = { page: 1, size: 10 };
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6271',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7ba91a',
      eventType: 0,
      amount: '999',
      canonicalTokenAddress: '0x00000000000000000000000000000000000000b0',
      canonicalTokenSymbol: 'STALE',
      canonicalTokenDecimals: 18,
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(
      createReceiptWithMessageSentLog({
        data: createERC20MessageData({
          canonicalTokenAddress: CANONICAL_ERC20_ADDRESS,
          decimals: 6,
          symbol: 'USDC',
          amount: 123_456n,
        }),
        to: DEST_ERC20_VAULT_ADDRESS,
        value: 0n,
      }),
    );
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0]).toEqual(
      expect.objectContaining({
        amount: 123_456n,
        canonicalTokenAddress: CANONICAL_ERC20_ADDRESS,
        decimals: 6,
        symbol: 'USDC',
        tokenType: TokenType.ERC20,
      }),
    );
  });

  test('getAllBridgeTransactionByAddress gives ETH 18 decimals even when the receipt is unavailable', async () => {
    // Given: the relayer nils canonicalToken for ETH, so the Go uint8 serializes as 0
    const relayerAPIService = new RelayerAPIService('http://example.com');
    const paginationParams = { page: 1, size: 10 };
    const relayerItem = createRelayerItem({
      id: 1553883,
      messageId: '6272',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7ba91b',
      eventType: 0,
      amount: '1000000000000000000',
      canonicalTokenSymbol: '',
      canonicalTokenDecimals: 0,
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    // And: the source-chain receipt fetch fails, so nothing later corrects the decimals
    mockedGetTransactionReceipt.mockResolvedValue(null as never);
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then: keeping 0 here renders one ETH as 1000000000000000000 in the details dialogs
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0]).toEqual(
      expect.objectContaining({
        amount: BigInt('1000000000000000000'),
        decimals: 18,
        symbol: 'ETH',
        tokenType: TokenType.ETH,
      }),
    );
  });

  test('getAllBridgeTransactionByAddress refreshes ERC721 metadata from the receipt message', async () => {
    // Given
    const relayerAPIService = new RelayerAPIService('http://example.com');
    const paginationParams = { page: 1, size: 10 };
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6271',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7ba91a',
      eventType: 0,
      amount: '999',
      canonicalTokenAddress: '0x00000000000000000000000000000000000000b0',
      canonicalTokenSymbol: 'STALE',
      canonicalTokenDecimals: 18,
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(
      createReceiptWithMessageSentLog({
        data: createERC721MessageData({
          canonicalTokenAddress: CANONICAL_ERC721_ADDRESS,
          symbol: 'TAIKO-NFT',
          tokenIds: [42n, 43n],
        }),
        to: DEST_ERC721_VAULT_ADDRESS,
        value: 0n,
      }),
    );
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0]).toEqual(
      expect.objectContaining({
        amount: 1n,
        canonicalTokenAddress: CANONICAL_ERC721_ADDRESS,
        decimals: undefined,
        symbol: 'TAIKO-NFT',
        tokenType: TokenType.ERC721,
      }),
    );
  });

  test('getAllBridgeTransactionByAddress refreshes ERC1155 metadata from the receipt message', async () => {
    // Given
    const relayerAPIService = new RelayerAPIService('http://example.com');
    const paginationParams = { page: 1, size: 10 };
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6271',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7ba91a',
      eventType: 0,
      amount: '999',
      canonicalTokenAddress: '0x00000000000000000000000000000000000000b0',
      canonicalTokenSymbol: 'STALE',
      canonicalTokenDecimals: 18,
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(
      createReceiptWithMessageSentLog({
        data: createERC1155MessageData({
          canonicalTokenAddress: CANONICAL_ERC1155_ADDRESS,
          symbol: 'TAIKO-ITEM',
          tokenIds: [42n, 43n],
          amounts: [2n, 3n],
        }),
        to: DEST_ERC1155_VAULT_ADDRESS,
        value: 0n,
      }),
    );
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0]).toEqual(
      expect.objectContaining({
        amount: 5n,
        canonicalTokenAddress: CANONICAL_ERC1155_ADDRESS,
        decimals: undefined,
        symbol: 'TAIKO-ITEM',
        tokenType: TokenType.ERC1155,
      }),
    );
  });

  test('getAllBridgeTransactionByAddress clears stale token metadata for a non-vault receipt message', async () => {
    // Given
    const relayerAPIService = new RelayerAPIService('http://example.com');
    const paginationParams = { page: 1, size: 10 };
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6271',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7ba91a',
      eventType: 1,
      amount: '999',
      canonicalTokenAddress: CANONICAL_ERC20_ADDRESS,
      canonicalTokenSymbol: 'STALE',
      canonicalTokenDecimals: 6,
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(
      createReceiptWithMessageSentLog({
        data: '0x12345678',
        to: USER_ADDRESS,
        value: 42n,
      }),
    );
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0]).toEqual(
      expect.objectContaining({
        amount: 42n,
        canonicalTokenAddress: undefined,
        decimals: 18,
        symbol: 'ETH',
        tokenType: TokenType.ETH,
      }),
    );
  });

  test('getAllBridgeTransactionByAddress disambiguates multiple receipt messages by relayer message id', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '6268',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7baa21',
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(
      createReceiptWithMessageSentLogs([
        { msgHash: OTHER_MSG_HASH, id: 9999n, logIndex: 1 },
        { msgHash: GOOD_MSG_HASH, id: 6268n, logIndex: 2 },
      ]),
    );
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(1);
    expect(result.txs[0].msgHash).toEqual(GOOD_MSG_HASH);
    expect(result.txs[0].message?.id).toEqual(6268n);
  });

  test('getAllBridgeTransactionByAddress excludes relayer data when multiple receipt messages stay ambiguous', async () => {
    // Given
    const baseUrl = 'http://example.com';
    const relayerAPIService = new RelayerAPIService(baseUrl);
    const paginationParams = { page: 1, size: 10 };
    // Neither the msgHash nor the id ties this row to one of the two logs, so there is nothing safe to
    // adopt. The relayer's hash is absent from the receipt, so keeping it would expose an unrelated message
    // to status checks and claim actions.
    const relayerItem = createRelayerItem({
      id: 1553882,
      messageId: '7777',
      msgHash: BAD_MSG_HASH,
      blockNumber: '0x7baa21',
    });

    mockedAxios.get.mockResolvedValue(createApiResponse([relayerItem]));
    mockedGetTransactionReceipt.mockResolvedValue(
      createReceiptWithMessageSentLogs([
        { msgHash: OTHER_MSG_HASH, id: 9999n, logIndex: 1 },
        { msgHash: GOOD_MSG_HASH, id: 6268n, logIndex: 2 },
      ]),
    );
    mockedReadContract.mockResolvedValue(MessageStatus.NEW);

    // When
    const result = await relayerAPIService.getAllBridgeTransactionByAddress(USER_ADDRESS, paginationParams, 167000);

    // Then
    expect(result.txs).toHaveLength(0);
    expect(mockedReadContract).not.toHaveBeenCalled();
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

  test('parseRelayerApiResponse also preserves the top-level amount and fee digits', () => {
    // Given: amounts above 2^53 wei (anything over ~0.009 ETH) lose digits as JSON doubles
    const exactAmount = 1_234_567_890_123_456_789n;
    const exactTopLevelFee = 9_007_199_254_740_993n;
    const rawResponse = `{"items":[{"amount":${exactAmount},"fee":${exactTopLevelFee},"data":{"Message":{"Fee":1}}}]}`;

    // When
    const parsed = parseRelayerApiResponse(rawResponse);

    // Then
    expect(BigInt(parsed.items[0].amount)).toEqual(exactAmount);
    expect(BigInt(parsed.items[0].fee!)).toEqual(exactTopLevelFee);
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
  fee = '467106403297320',
  status = MessageStatus.NEW,
  srcChainId = '167000',
  destChainId = '1',
  srcTxHash = SRC_TX_HASH,
  amount = '185000000000000000',
  claimedBy = '',
  processedTxHash = undefined,
  relayerFee = '0',
  eventType = 0,
  canonicalTokenAddress = '0x0000000000000000000000000000000000000000',
  canonicalTokenSymbol = 'ETH',
  canonicalTokenDecimals = 18,
}: {
  id: number;
  messageId: string;
  msgHash: Hash;
  blockNumber: Hex;
  fee?: string;
  status?: MessageStatus;
  srcChainId?: string;
  destChainId?: string;
  srcTxHash?: Hash;
  amount?: string;
  claimedBy?: string;
  processedTxHash?: Hash;
  relayerFee?: string;
  eventType?: number;
  canonicalTokenAddress?: Address;
  canonicalTokenSymbol?: string;
  canonicalTokenDecimals?: number;
}) {
  return {
    id,
    name: 'MessageSent',
    data: {
      Message: {
        Id: messageId,
        Fee: fee,
        GasLimit: 806657,
        From: USER_ADDRESS,
        SrcChainId: srcChainId,
        SrcOwner: USER_ADDRESS,
        DestChainId: destChainId,
        DestOwner: USER_ADDRESS,
        To: USER_ADDRESS,
        RefundTo: USER_ADDRESS,
        Value: '185000000000000000',
        Data: '0x',
        Memo: '',
      },
      Raw: {
        address: TAIKO_BRIDGE_ADDRESS,
        transactionHash: srcTxHash,
        transactionIndex: '0x1',
        blockNumber,
      },
    },
    status,
    eventType,
    chainID: 167000,
    canonicalTokenAddress,
    canonicalTokenSymbol,
    canonicalTokenName: 'Ether',
    canonicalTokenDecimals,
    amount,
    msgHash,
    messageOwner: USER_ADDRESS,
    event: 'MessageSent',
    claimedBy,
    processedTxHash,
    fee: relayerFee,
    isProfitable: false,
    isProfitableEvaluatedAt: '',
  };
}

function createApiResponse(items: ReturnType<typeof createRelayerItem>[]) {
  return {
    data: {
      page: 1,
      size: 10,
      total: items.length,
      total_pages: 1,
      max_page: 1,
      first: true,
      last: true,
      visible: items.length,
      items,
    },
    status: 200,
  };
}

function createReceiptWithMessageSentLog(
  messageLog: Partial<MessageSentLogInput> = {},
): Awaited<ReturnType<typeof getTransactionReceipt>> {
  return createReceiptWithMessageSentLogs([{ msgHash: GOOD_MSG_HASH, ...messageLog }]);
}

type MessageSentLogInput = {
  msgHash: Hash;
  id: bigint;
  fee: bigint;
  gasLimit: number;
  srcChainId: bigint;
  destChainId: bigint;
  logIndex: number;
  to: Address;
  value: bigint;
  data: Hex;
};

function createReceiptWithMessageSentLogs(
  messageLogs: Partial<MessageSentLogInput>[],
): Awaited<ReturnType<typeof getTransactionReceipt>> {
  return {
    status: 'success',
    cumulativeGasUsed: 210721n,
    logs: messageLogs.map(createMessageSentLog),
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

function createMessageSentLog(messageLog: Partial<MessageSentLogInput>) {
  const {
    msgHash = GOOD_MSG_HASH,
    id = 6268n,
    fee = 467_106_403_297_320n,
    gasLimit = 806657,
    srcChainId = 167000n,
    destChainId = 1n,
    logIndex = 1,
    to = USER_ADDRESS,
    value = 185_000_000_000_000_000n,
    data = '0x',
  } = messageLog;

  const encodedData = encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'id', type: 'uint64' },
          { name: 'fee', type: 'uint64' },
          { name: 'gasLimit', type: 'uint32' },
          { name: 'from', type: 'address' },
          { name: 'srcChainId', type: 'uint64' },
          { name: 'srcOwner', type: 'address' },
          { name: 'destChainId', type: 'uint64' },
          { name: 'destOwner', type: 'address' },
          { name: 'to', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
        ],
      },
    ],
    [
      {
        id,
        fee,
        gasLimit,
        from: USER_ADDRESS,
        srcChainId,
        srcOwner: USER_ADDRESS,
        destChainId,
        destOwner: USER_ADDRESS,
        to,
        value,
        data,
      },
    ],
  );

  return {
    address: TAIKO_BRIDGE_ADDRESS,
    blockHash: '0xb88411608e875be7e5f9cdcde5f80d749e6c23c27ffa2ab5c598c760050c02a2',
    blockNumber: 8104481n,
    logIndex,
    transactionHash: SRC_TX_HASH,
    transactionIndex: 1,
    removed: false,
    topics: [MESSAGE_SENT_EVENT_TOPIC, msgHash],
    data: encodedData,
  };
}

function createERC20MessageData({
  canonicalTokenAddress,
  decimals,
  symbol,
  amount,
}: {
  canonicalTokenAddress: Address;
  decimals: number;
  symbol: string;
  amount: bigint;
}) {
  const invocationData = encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'chainId', type: 'uint64' },
          { name: 'addr', type: 'address' },
          { name: 'decimals', type: 'uint8' },
          { name: 'symbol', type: 'string' },
          { name: 'name', type: 'string' },
        ],
      },
      { type: 'address' },
      { type: 'address' },
      { type: 'uint256' },
    ],
    [
      {
        chainId: 167000n,
        addr: canonicalTokenAddress,
        decimals,
        symbol,
        name: `${symbol} Token`,
      },
      USER_ADDRESS,
      USER_ADDRESS,
      amount,
    ],
  );

  return encodeFunctionData({
    abi: erc20VaultAbi,
    functionName: 'onMessageInvocation',
    args: [invocationData],
  });
}

function createERC721MessageData({
  canonicalTokenAddress,
  symbol,
  tokenIds,
}: {
  canonicalTokenAddress: Address;
  symbol: string;
  tokenIds: bigint[];
}) {
  const invocationData = encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'chainId', type: 'uint64' },
          { name: 'addr', type: 'address' },
          { name: 'symbol', type: 'string' },
          { name: 'name', type: 'string' },
        ],
      },
      { type: 'address' },
      { type: 'address' },
      { type: 'uint256[]' },
    ],
    [
      {
        chainId: 167000n,
        addr: canonicalTokenAddress,
        symbol,
        name: `${symbol} Collection`,
      },
      USER_ADDRESS,
      USER_ADDRESS,
      tokenIds,
    ],
  );

  return encodeFunctionData({
    abi: erc721VaultAbi,
    functionName: 'onMessageInvocation',
    args: [invocationData],
  });
}

function createERC1155MessageData({
  canonicalTokenAddress,
  symbol,
  tokenIds,
  amounts,
}: {
  canonicalTokenAddress: Address;
  symbol: string;
  tokenIds: bigint[];
  amounts: bigint[];
}) {
  const invocationData = encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'chainId', type: 'uint64' },
          { name: 'addr', type: 'address' },
          { name: 'symbol', type: 'string' },
          { name: 'name', type: 'string' },
        ],
      },
      { type: 'address' },
      { type: 'address' },
      { type: 'uint256[]' },
      { type: 'uint256[]' },
    ],
    [
      {
        chainId: 167000n,
        addr: canonicalTokenAddress,
        symbol,
        name: `${symbol} Collection`,
      },
      USER_ADDRESS,
      USER_ADDRESS,
      tokenIds,
      amounts,
    ],
  );

  return encodeFunctionData({
    abi: erc1155VaultAbi,
    functionName: 'onMessageInvocation',
    args: [invocationData],
  });
}
