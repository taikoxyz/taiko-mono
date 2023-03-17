import { BigNumber, BigNumberish, ethers } from 'ethers';

import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';
import { MessageStatus } from '../domain/message';
import type { BridgeTransaction } from '../domain/transactions';
import { TKOToken } from '../token/tokens';
import { StorageService } from './StorageService';

const mockStorage = {
  getItem: jest.fn(),
};

const mockProvider = {
  getTransactionReceipt: jest.fn(),
};

const mockContract = {
  queryFilter: jest.fn(),
  getMessageStatus: jest.fn(),
  symbol: jest.fn(),
  filters: {
    ERC20Sent: jest.fn(),
  },
};

jest.mock('ethers', () => ({
  /* eslint-disable-next-line */
  ...(jest.requireActual('ethers') as object),
  Contract: function () {
    return mockContract;
  },
}));

const providerMap: Map<number, ethers.providers.JsonRpcProvider> = new Map<
  number,
  ethers.providers.JsonRpcProvider
>();

providerMap.set(
  L1_CHAIN_ID,
  mockProvider as unknown as ethers.providers.JsonRpcProvider,
);
providerMap.set(
  L2_CHAIN_ID,
  mockProvider as unknown as ethers.providers.JsonRpcProvider,
);

const mockTx: BridgeTransaction = {
  hash: '0x123',
  from: '0x123',
  status: MessageStatus.New,
  fromChainId: L1_CHAIN_ID,
  toChainId: L2_CHAIN_ID,
};

const mockTxs: BridgeTransaction[] = [mockTx];

const mockTxReceipt = {
  blockNumber: 1,
};

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
  },
};

const mockQuery = [mockEvent];

const mockErc20Query = [mockErc20Event];

jest.mock('../store/bridge', () => ({
  chainIdToTokenVaultAddress: jest.fn(),
}));

jest.mock('svelte/store', () => ({
  get: function () {
    return {
      get: jest.fn(),
    };
  },
}));

describe('storage tests', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('gets all transactions by address, no transactions in list', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return '[]';
    });

    mockContract.symbol.mockImplementation(() => {
      return TKOToken.symbol;
    });

    const svc = new StorageService(mockStorage as any, providerMap);

    const addresses = await svc.GetAllByAddress('0x123', L2_CHAIN_ID);

    expect(addresses).toEqual([]);
  });

  it('gets all transactions by address, no receipt', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify(mockTxs);
    });

    mockContract.getMessageStatus.mockImplementation(() => {
      return MessageStatus.New;
    });

    mockContract.queryFilter.mockImplementation(() => {
      return mockQuery;
    });

    mockContract.symbol.mockImplementation(() => {
      return TKOToken.symbol;
    });

    const svc = new StorageService(mockStorage as any, providerMap);

    const addresses = await svc.GetAllByAddress('0x123', L1_CHAIN_ID);

    expect(addresses).toEqual([
      {
        from: '0x123',
        hash: '0x123',
        fromChainId: L1_CHAIN_ID,
        status: 0,
        toChainId: L2_CHAIN_ID,
      },
    ]);
  });

  it('gets all transactions by address, no event', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify(mockTxs);
    });

    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return mockTxReceipt;
    });

    mockContract.getMessageStatus.mockImplementation(() => {
      return MessageStatus.New;
    });

    mockContract.queryFilter.mockImplementation(() => {
      return [];
    });

    mockContract.symbol.mockImplementation(() => {
      return TKOToken.symbol;
    });

    const svc = new StorageService(mockStorage as any, providerMap);

    const addresses = await svc.GetAllByAddress('0x123', L1_CHAIN_ID);

    expect(addresses).toEqual([
      {
        from: '0x123',
        hash: '0x123',
        fromChainId: L1_CHAIN_ID,
        receipt: {
          blockNumber: 1,
        },
        status: 0,
        toChainId: L2_CHAIN_ID,
      },
    ]);
  });

  it('gets all transactions by address', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify(mockTxs);
    });

    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return mockTxReceipt;
    });

    mockContract.getMessageStatus.mockImplementation(() => {
      return MessageStatus.New;
    });

    mockContract.queryFilter.mockImplementation(
      (name: string, from: BigNumberish, to: BigNumberish) => {
        if (name === 'ERC20Sent') {
          return mockErc20Query;
        }

        return mockQuery;
      },
    );

    mockContract.symbol.mockImplementation(() => {
      return TKOToken.symbol;
    });

    const svc = new StorageService(mockStorage as any, providerMap);

    const addresses = await svc.GetAllByAddress('0x123', L1_CHAIN_ID);

    expect(addresses).toEqual([
      {
        amountInWei: BigNumber.from(0x64),
        hash: '0x123',
        from: '0x123',
        message: {
          owner: '0x123',
        },
        receipt: {
          blockNumber: 1,
        },
        msgHash: '0x456',
        status: 0,
        fromChainId: L1_CHAIN_ID,
        toChainId: L2_CHAIN_ID,
        symbol: 'TKO',
      },
    ]);
  });

  it('gets all transactions by address, CHAIN_TKO', async () => {
    mockTx.toChainId = L2_CHAIN_ID;
    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify(mockTxs);
    });

    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return mockTxReceipt;
    });

    mockContract.getMessageStatus.mockImplementation(() => {
      return MessageStatus.New;
    });

    mockContract.queryFilter.mockImplementation(
      (name: string, from: BigNumberish, to: BigNumberish) => {
        if (name === 'ERC20Sent') {
          return mockErc20Query;
        }

        return mockQuery;
      },
    );

    mockContract.symbol.mockImplementation(() => {
      return TKOToken.symbol;
    });

    const svc = new StorageService(mockStorage as any, providerMap);

    const addresses = await svc.GetAllByAddress('0x123', L2_CHAIN_ID);

    expect(addresses).toEqual([
      {
        amountInWei: BigNumber.from(0x64),
        from: '0x123',
        hash: '0x123',
        message: {
          owner: '0x123',
        },
        receipt: {
          blockNumber: 1,
        },
        msgHash: '0x456',
        status: 0,
        symbol: 'TKO',
        fromChainId: L1_CHAIN_ID,
        toChainId: L2_CHAIN_ID,
      },
    ]);
  });
});
