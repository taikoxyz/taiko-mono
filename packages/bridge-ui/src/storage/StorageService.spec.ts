import { BigNumber, BigNumberish } from 'ethers';
import { MessageStatus } from '../domain/message';
import { StorageService } from './StorageService';
import type { BridgeTransaction } from '../domain/transactions';
import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';
import { TKOToken } from '../token/tokens';
import { providers } from '../provider/providers';

jest.mock('../constants/envVars');

const mockStorage = {
  getItem: jest.fn(),
  setItem: jest.fn(),
};

const mockProvider = {
  getTransactionReceipt: jest.fn(),
  waitForTransaction: jest.fn(),
};

providers[L1_CHAIN_ID] = mockProvider as any;
providers[L2_CHAIN_ID] = mockProvider as any;

const mockContract = {
  queryFilter: jest.fn(),
  getMessageStatus: jest.fn(),
  symbol: jest.fn(),
  filters: {
    ERC20Sent: jest.fn(),
  },
};

jest.mock('ethers', () => ({
  ...jest.requireActual('ethers'),
  Contract: function () {
    return mockContract;
  },
}));

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

    const svc = new StorageService(mockStorage as any, providers);

    const addresses = await svc.getAllByAddress('0x123', L2_CHAIN_ID);

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

    const svc = new StorageService(mockStorage as any, providers);

    const addresses = await svc.getAllByAddress('0x123', L1_CHAIN_ID);

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

    const svc = new StorageService(mockStorage as any, providers);

    const addresses = await svc.getAllByAddress('0x123', L1_CHAIN_ID);

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

    const svc = new StorageService(mockStorage as any, providers);

    const addresses = await svc.getAllByAddress('0x123', L1_CHAIN_ID);

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

    const svc = new StorageService(mockStorage as any, providers);

    const addresses = await svc.getAllByAddress('0x123', L2_CHAIN_ID);

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

  it('get transaction by hash', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify(mockTxs);
    });

    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return mockTxReceipt;
    });

    mockProvider.waitForTransaction.mockImplementation(() => {
      return;
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

    const svc = new StorageService(mockStorage as any, providers);

    const addresses = await svc.getTransactionByHash('0x123', mockTx.hash);

    expect(addresses).toEqual({
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
    });
  });

  it('updates storage by address', () => {
    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify(mockTxs);
    });

    const svc = new StorageService(mockStorage as any, providers);

    const newTx = { ...mockTx } as BridgeTransaction;
    newTx.status = MessageStatus.Done;

    svc.updateStorageByAddress('0x123', [newTx]);

    expect(mockStorage.setItem).toHaveBeenCalledWith(
      'transactions-0x123',
      JSON.stringify([newTx]),
    );
  });
});
