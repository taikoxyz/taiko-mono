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
      data: '0x',
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

describe('storage tests', () => {
  beforeAll(() => {
    mockProvider.waitForTransaction.mockImplementation(() => {
      return;
    });

    mockContract.getMessageStatus.mockImplementation(() => {
      return MessageStatus.New;
    });
  });

  beforeEach(() => {
    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify(mockTxs);
    });

    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return mockTxReceipt;
    });
  });

  it('gets all transactions by address, no transactions in list', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return '[]';
    });

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    expect(txs).toEqual([]);
  });

  it('gets all transactions by address, no receipt', async () => {
    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return null;
    });

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    expect(txs).toEqual([mockTx]);
  });

  it('gets all transactions by address, no event', async () => {
    mockContract.queryFilter.mockImplementation(() => {
      return [];
    });

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    expect(txs).toEqual([
      {
        ...mockTx,
        receipt: {
          blockNumber: 1,
        },
      },
    ]);
  });

  it('gets all transactions by address, ETH (message.data === "0x")', async () => {
    mockContract.queryFilter.mockImplementation(() => {
      return mockQuery;
    });

    mockContract.symbol.mockImplementation(() => {
      return 'ETH';
    });

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    expect(txs).toEqual([
      {
        ...mockTx,
        receipt: {
          blockNumber: 1,
        },
        msgHash: mockEvent.args.msgHash,
        message: mockEvent.args.message,
      },
    ]);
  });

  it('gets all transactions by address, ERC20 (message.data !== "0x")', async () => {
    mockContract.queryFilter.mockImplementation(() => {
      return mockErc20Query;
    });

    mockContract.symbol.mockImplementation(() => {
      return TKOToken.symbol;
    });

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    expect(txs).toEqual([
      {
        ...mockTx,
        amountInWei: BigNumber.from(0x64),
        receipt: {
          blockNumber: 1,
        },
        symbol: TKOToken.symbol,
        msgHash: mockErc20Event.args.msgHash,
        message: mockErc20Event.args.message,
      },
    ]);
  });

  it('gets all transactions by address, no receipt', async () => {
    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return null;
    });

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x123', mockTx.hash);

    expect(tx).toBeUndefined();
  });

  it('gets all transactions by address, no event', async () => {
    mockContract.queryFilter.mockImplementation(() => {
      return [];
    });

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x123', mockTx.hash);

    expect(tx).toBeUndefined();
  });

  it('get transaction by hash, ETH (message.data === "0x")', async () => {
    mockContract.queryFilter.mockImplementation(() => {
      return mockQuery;
    });

    mockContract.symbol.mockImplementation(() => {
      return 'ETH';
    });

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x123', mockTx.hash);

    expect(tx).toEqual({
      ...mockTx,
      message: mockEvent.args.message,
      receipt: {
        blockNumber: 1,
      },
      msgHash: mockEvent.args.msgHash,
      status: 0,
    });
  });

  it('get transaction by hash, ERC20 (message.data !== "0x")', async () => {
    mockContract.queryFilter.mockImplementation(() => {
      return mockErc20Query;
    });

    mockContract.symbol.mockImplementation(() => {
      return TKOToken.symbol;
    });

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x123', mockTx.hash);

    expect(tx).toEqual({
      ...mockTx,
      amountInWei: BigNumber.from(0x64),
      message: mockErc20Event.args.message,
      receipt: {
        blockNumber: 1,
      },
      msgHash: mockErc20Event.args.msgHash,
      status: 0,
      symbol: TKOToken.symbol,
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

  it('handles invalid JSON', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return 'invalid json';
    });

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    expect(txs).toEqual([]);
  });
});
