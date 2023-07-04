import axios from 'axios';
import { ethers } from 'ethers';
import type { Address } from 'wagmi';

import {
  L1_CHAIN_ID,
  L2_BRIDGE_ADDRESS,
  L2_CHAIN_ID,
  RELAYER_URL,
} from '../constants/envVars';
import { MessageStatus } from '../domain/message';
import type { ProvidersRecord } from '../domain/provider';
import type { APIResponseTransaction } from '../domain/relayerApi';
import blockInfoJson from './__fixtures__/blockInfo.json';
import eventsJson from './__fixtures__/events.json';
import { RelayerAPIService } from './RelayerAPIService';

jest.mock('axios');
jest.mock('../constants/envVars');
jest.mock('../provider/providers');

const mockContract = {
  queryFilter: jest.fn(),
  getMessageStatus: jest.fn(),
  symbol: jest.fn(),
  decimals: jest.fn(),
  filters: {
    ERC20Sent: () => 'ERC20Sent',
  },
};

jest.mock('ethers', () => ({
  ...jest.requireActual('ethers'),
  Contract: function () {
    return mockContract;
  },
}));

const walletAddress: Address = '0x33C887d229B5b99cdfa06B02102f8F75411C56B8';

const mockProviders = {
  [L1_CHAIN_ID]: {
    getTransactionReceipt: jest.fn(),
  },
  [L2_CHAIN_ID]: {
    getTransactionReceipt: jest.fn(),
  },
} as unknown as ProvidersRecord;

const mockTxReceipt = {
  blockNumber: 1,
} as ethers.providers.TransactionReceipt;

const mockErc20Event = {
  args: {
    token: '0x123',
    amount: '100',
    msgHash: '0x123',
    message: {
      owner: walletAddress,
      data: '0x789',
    },
  },
};

const mockErc20Query = [mockErc20Event];

const baseUrl = RELAYER_URL.replace(/\/$/, '');
const relayerApi = new RelayerAPIService(RELAYER_URL, mockProviders);

describe('RelayerAPIService', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    jest
      .mocked(mockProviders[L1_CHAIN_ID].getTransactionReceipt)
      .mockResolvedValue(mockTxReceipt);

    jest
      .mocked(mockProviders[L2_CHAIN_ID].getTransactionReceipt)
      .mockResolvedValue(mockTxReceipt);

    mockContract.getMessageStatus.mockResolvedValue(MessageStatus.New);
    mockContract.queryFilter.mockResolvedValue(mockErc20Query);
    mockContract.symbol.mockResolvedValue('BLL');
    mockContract.decimals.mockResolvedValue(18);
  });

  it('should get transactions from API', async () => {
    jest.mocked(axios.get).mockResolvedValueOnce({
      data: eventsJson,
    });

    const data = await relayerApi.getTransactionsFromAPI({
      address: walletAddress,
      chainID: 1,
      event: 'MessageSent',
    });

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
      params: { address: walletAddress, chainID: 1, event: 'MessageSent' },
    });

    // Test return value
    expect(data.items.length).toEqual(eventsJson.items.length);
  });

  it('should return an empty list when API fails', async () => {
    const args = {
      address: walletAddress,
      chainID: 1,
      event: 'MessageSent',
    };

    jest.mocked(axios.get).mockRejectedValueOnce(new Error('BAM!!'));

    await expect(relayerApi.getTransactionsFromAPI(args)).rejects.toThrowError(
      'could not fetch transactions from API',
    );

    // Status >= 400 is considered an error
    jest.mocked(axios.get).mockResolvedValueOnce({
      status: 500,
    });

    await expect(relayerApi.getTransactionsFromAPI(args)).rejects.toThrowError(
      'could not fetch transactions from API',
    );

    // Status < 400 is considered a success
    jest.mocked(axios.get).mockResolvedValueOnce({
      status: 200,
      data: eventsJson,
    });

    await expect(relayerApi.getTransactionsFromAPI(args)).resolves.toEqual(
      eventsJson,
    );
  });

  it('should get empty list of transactions', async () => {
    const mockPaginationInfo = {
      page: 0,
      size: 100,
      max_page: 1,
      total_pages: 1,
      total: 0,
      last: false,
      first: true,
    };

    jest.mocked(axios.get).mockResolvedValueOnce({
      data: {
        items: [],
        ...mockPaginationInfo,
        visible: 0,
      },
    });

    const { txs, paginationInfo } =
      await relayerApi.getAllBridgeTransactionByAddress(walletAddress, {
        page: 0,
        size: 100,
      });

    expect(txs).toEqual([]);
    expect(paginationInfo).toEqual(mockPaginationInfo);
  });

  it('should get filtered bridge transactions by address', async () => {
    // TODO: use structuredClone(), instead of JSON.parse(JSON.stringify())
    const items = JSON.parse(
      JSON.stringify(eventsJson.items),
    ) as APIResponseTransaction[];

    // Ignore transactions from unsupported chains
    items[0].chainID = items[0].data.Message.SrcChainId = 666;

    // Filter out duplicate transactions
    items[2].data.Raw.transactionHash = items[1].data.Raw.transactionHash;

    // Filter out transactions with wrong bridge address
    items[4].data.Raw.address = '0x666';

    jest.mocked(axios.get).mockResolvedValueOnce({
      data: { ...eventsJson, items },
    });

    const { txs } = await relayerApi.getAllBridgeTransactionByAddress(
      walletAddress,
      {
        page: 0,
        size: 100,
      },
    );

    expect(txs.length).toBe(items.length - 3);
  });

  it('should get only L2 => L1 transactions by address', async () => {
    const items = JSON.parse(
      JSON.stringify(eventsJson.items),
    ) as APIResponseTransaction[];

    // 5th items is L2 => L1
    items[5].chainID = items[5].data.Message.SrcChainId = L2_CHAIN_ID;
    items[5].data.Raw.address = L2_BRIDGE_ADDRESS;
    items[5].data.Message.DestChainId = L1_CHAIN_ID;

    jest.mocked(axios.get).mockResolvedValueOnce({
      data: { ...eventsJson, items },
    });

    // Non of the transactions L1 => L2 have receipts
    jest
      .mocked(mockProviders[L1_CHAIN_ID].getTransactionReceipt)
      .mockResolvedValue(null);

    const { txs } = await relayerApi.getAllBridgeTransactionByAddress(
      walletAddress,
      {
        page: 0,
        size: 100,
      },
    );

    expect(txs.length).toBe(1);

    const chainIds = txs.map((tx) => tx.message.srcChainId);
    expect(chainIds).not.toContain(L1_CHAIN_ID);
  });

  it('should get all transactions by address', async () => {
    const items = JSON.parse(
      JSON.stringify(eventsJson.items),
    ) as APIResponseTransaction[];

    // We make one ETH bridge transaction
    items[7].data.Message.Data = '';
    items[7].canonicalTokenAddress = ethers.constants.AddressZero;

    jest.mocked(axios.get).mockResolvedValueOnce({
      data: { ...eventsJson, items },
    });

    await relayerApi.getAllBridgeTransactionByAddress(walletAddress, {
      page: 0,
      size: 100,
    });

    expect(
      mockProviders[L1_CHAIN_ID].getTransactionReceipt,
    ).toHaveBeenCalledTimes(10);

    expect(mockContract.getMessageStatus).toHaveBeenCalledTimes(10);
    expect(mockContract.queryFilter).toHaveBeenCalledTimes(9);
    expect(mockContract.symbol).toHaveBeenCalledTimes(9);
    expect(mockContract.decimals).toHaveBeenCalledTimes(9);
  });

  it('should not get transactions with wrong address', async () => {
    jest.mocked(axios.get).mockResolvedValueOnce({
      data: eventsJson,
    });

    const { txs } = await relayerApi.getAllBridgeTransactionByAddress(
      '0xWrongAddress',
      {
        page: 0,
        size: 100,
      },
    );

    expect(txs.length).toEqual(0);
  });

  it('should show New transactions on top', async () => {
    let count = 0;
    // Let's make some transactions to be New
    mockContract.getMessageStatus.mockImplementation(() => {
      count++;

      switch (count) {
        case 3:
        case 5:
        case 9:
          return Promise.resolve(MessageStatus.New);
        default:
          return Promise.resolve(MessageStatus.Done);
      }
    });

    jest.mocked(axios.get).mockResolvedValueOnce({
      data: eventsJson,
    });

    const { txs } = await relayerApi.getAllBridgeTransactionByAddress(
      walletAddress,
      {
        page: 0,
        size: 100,
      },
    );

    const statuses = txs.map((tx) => tx.status);

    expect(statuses).toEqual([
      MessageStatus.New,
      MessageStatus.New,
      MessageStatus.New,
      //----------------//
      MessageStatus.Done,
      MessageStatus.Done,
      MessageStatus.Done,
      MessageStatus.Done,
      MessageStatus.Done,
      MessageStatus.Done,
      MessageStatus.Done,
    ]);
  });

  // TODO: there are still some branches to cover here

  it('should get block info', async () => {
    jest.mocked(axios.get).mockResolvedValue({
      data: blockInfoJson,
    });

    const blockInfo = await relayerApi.getBlockInfo();

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/blockInfo`);

    // Test return value
    expect(blockInfo).toEqual(
      new Map([
        [blockInfoJson.data[0].chainID, blockInfoJson.data[0]],
        [blockInfoJson.data[1].chainID, blockInfoJson.data[1]],
      ]),
    );
  });

  it('handles API failure', async () => {
    jest.mocked(axios.get).mockRejectedValueOnce(new Error('BAM!!'));

    await expect(relayerApi.getBlockInfo()).rejects.toThrowError(
      'failed to fetch block info',
    );

    // Status >= 400 is considered an error
    jest.mocked(axios.get).mockResolvedValueOnce({
      status: 400,
    });

    await expect(relayerApi.getBlockInfo()).rejects.toThrowError(
      'failed to fetch block info',
    );
  });
});
