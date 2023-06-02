import type { Address } from '@wagmi/core';
import axios from 'axios';
import type { ethers } from 'ethers';

import { L1_CHAIN_ID, L2_CHAIN_ID, RELAYER_URL } from '../constants/envVars';
import { MessageStatus } from '../domain/message';
import type { ProvidersRecord } from '../domain/provider';
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
  filters: {
    // Returns this string to help us
    // identify the filter in the tests
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

const mockEvent = {
  args: {
    message: {
      owner: '0x123',
    },
    msgHash: '0x456',
    amount: '100',
  },
};

const mockErc20Event = {
  args: {
    amount: '100',
    msgHash: '0x456',
    message: {
      owner: '0x123',
      data: '0x789',
    },
  },
};

const mockQuery = [mockEvent];

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
    mockContract.queryFilter.mockResolvedValue(mockQuery);
    mockContract.symbol.mockResolvedValue('BLL');
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

  it('cannot get transactions from API', async () => {
    jest.mocked(axios.get).mockRejectedValueOnce(new Error('BAM!!'));

    await expect(
      relayerApi.getTransactionsFromAPI({
        address: walletAddress,
        chainID: 1,
        event: 'MessageSent',
      }),
    ).rejects.toThrowError('could not fetch transactions from API');
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

    // Test parameters
    expect(axios.get).toHaveBeenCalledWith(`${baseUrl}/events`, {
      params: {
        address: walletAddress,
        event: 'MessageSent',
        page: 0,
        size: 100,
      },
    });

    // There are transactions with duplicate transactionHash.
    // We are expecting here less bridge txs than what we
    // have in the fixture.
    expect(txs.length).toBeLessThan(eventsJson.items.length);
  });

  it('should get only L2 => L1 transactions by address', async () => {
    jest.mocked(axios.get).mockResolvedValueOnce({
      data: eventsJson,
    });

    // Transactions with no receipt are not included
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

    const chainIds = txs.map((tx) => tx.message.srcChainId);
    expect(chainIds).not.toContain(L1_CHAIN_ID);
  });

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

  it('cannot get block info', async () => {
    jest.mocked(axios.get).mockRejectedValueOnce(new Error('BAM!!'));

    await expect(relayerApi.getBlockInfo()).rejects.toThrowError(
      'failed to fetch block info',
    );
  });
});
