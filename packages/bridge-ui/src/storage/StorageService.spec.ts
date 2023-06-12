import { BigNumber } from 'ethers';

import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';
import { MessageStatus } from '../domain/message';
import type { BridgeTransaction } from '../domain/transaction';
import { providers } from '../provider/providers';
import { TKOToken } from '../token/tokens';
import { StorageService } from './StorageService';

jest.mock('../constants/envVars');

const mockStorage = {
  getItem: jest.fn(),
  setItem: jest.fn(),
};

const mockProvider = {
  getTransactionReceipt: jest.fn(),
  waitForTransaction: jest.fn(),
};

const mockContract = {
  queryFilter: jest.fn(),
  getMessageStatus: jest.fn(),
  symbol: jest.fn(),
  decimals: jest.fn(),
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

const mockTx: BridgeTransaction = {
  hash: '0x123',
  from: '0x123',
  status: MessageStatus.New,
  srcChainId: L1_CHAIN_ID,
  destChainId: L2_CHAIN_ID,
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
      return Promise.resolve(mockTxReceipt);
    });

    mockContract.getMessageStatus.mockImplementation(() => {
      return MessageStatus.New;
    });
  });

  beforeEach(() => {
    providers[L1_CHAIN_ID] = mockProvider as any;
    providers[L2_CHAIN_ID] = mockProvider as any;

    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify(mockTxs);
    });

    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return mockTxReceipt;
    });

    mockContract.queryFilter.mockReset();
  });

  it('handles invalid JSON when getting all transactions', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return 'invalid json';
    });

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    expect(txs).toEqual([]);
  });

  it('gets all transactions by address where tx.from !== address', async () => {
    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x666');

    expect(txs).toEqual([]);
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

  it('gets all transactions by address, no MessageSent event', async () => {
    mockContract.queryFilter.mockImplementation(() => {
      return [];
    });

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    expect(txs).toEqual([
      {
        ...mockTx,
        receipt: { blockNumber: 1 },
      },
    ]);
  });

  it('gets all transactions by address, ETH transfer', async () => {
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
        receipt: { blockNumber: 1 },
        msgHash: mockEvent.args.msgHash,
        message: mockEvent.args.message,
      },
    ]);
  });

  it('gets all transactions by address, no ERC20Sent event', async () => {
    mockContract.queryFilter.mockImplementation((filter: string) => {
      if (filter === 'ERC20Sent') return [];
      return mockErc20Query; // MessageSent
    });

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    // There is no symbol nor amount
    expect(txs).toEqual([
      {
        ...mockTx,
        receipt: { blockNumber: 1 },
        msgHash: mockErc20Event.args.msgHash,
        message: mockErc20Event.args.message,
      },
    ]);
  });

  it('gets all transactions by address, ERC20 transfer', async () => {
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
        receipt: {
          blockNumber: 1,
        },
        msgHash: mockErc20Event.args.msgHash,
        message: mockErc20Event.args.message,

        // We should have these two
        symbol: TKOToken.symbol,
        amount: BigNumber.from(0x64),
      },
    ]);
  });

  it('ignores txs from unsupported chains when getting all txs', async () => {
    providers[L1_CHAIN_ID] = undefined;

    const svc = new StorageService(mockStorage as any, providers);

    const txs = await svc.getAllByAddress('0x123');

    expect(txs).toEqual([]);
  });

  it('handles invalid JSON when getting transaction by hash', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return 'invalid json';
    });

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x123', mockTx.hash);

    expect(tx).toBeUndefined();
  });

  it('gets transaction by hash, no receipt', async () => {
    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return null;
    });

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x123', mockTx.hash);

    expect(tx).toEqual(tx);
  });

  it('gets transaction by hash, no event', async () => {
    mockContract.queryFilter.mockImplementation(() => {
      return [];
    });

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x123', mockTx.hash);

    expect(tx).toEqual({
      ...tx,
      receipt: { blockNumber: 1 },
    });
  });

  it('gets transaction by hash where tx.from !== address', async () => {
    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x666', mockTx.hash);

    expect(tx).toBeUndefined();
  });

  it('gets transaction by hash, ETH transfer', async () => {
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
      receipt: { blockNumber: 1 },
      msgHash: mockEvent.args.msgHash,
      status: 0,
    });
  });

  it('gets transaction by hash, no ERC20Sent event', async () => {
    mockContract.queryFilter.mockImplementation((filter: string) => {
      if (filter === 'ERC20Sent') return [];
      return mockErc20Query; // MessageSent
    });

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x123', mockTx.hash);

    // There is no symbol nor amount
    expect(tx).toEqual({
      ...mockTx,
      receipt: { blockNumber: 1 },
      msgHash: mockErc20Event.args.msgHash,
      message: mockErc20Event.args.message,
    });
  });

  it('gets transaction by hash, ERC20 transfer', async () => {
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
      amount: BigNumber.from(0x64),
      message: mockErc20Event.args.message,
      receipt: {
        blockNumber: 1,
      },
      msgHash: mockErc20Event.args.msgHash,
      status: 0,
      symbol: TKOToken.symbol,
    });
  });

  it('ignores txs from unsupported chains when getting txs by hash', async () => {
    providers[L1_CHAIN_ID] = undefined;

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getTransactionByHash('0x123', mockTx.hash);

    expect(tx).toBeUndefined();
  });

  it('makes sure New transactions are on top of the list', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify([
        { ...mockTx, status: MessageStatus.New },
        { ...mockTx, status: MessageStatus.Done },
        { ...mockTx, status: MessageStatus.Retriable },
        { ...mockTx, status: MessageStatus.New },
      ]);
    });

    mockContract.queryFilter.mockImplementation(() => {
      return [];
    });

    const svc = new StorageService(mockStorage as any, providers);

    const tx = await svc.getAllByAddress('0x123');
    const statuses = tx.map((t) => t.status);

    // New txs should be on top
    expect(statuses).toEqual([
      MessageStatus.New,
      MessageStatus.New,
      //----------------//
      MessageStatus.Done,
      MessageStatus.Retriable,
    ]);
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

    // Should empty storerage if no txs are passed in
    svc.updateStorageByAddress('0x123');

    expect(mockStorage.setItem).toHaveBeenCalledWith(
      'transactions-0x123',
      JSON.stringify([]),
    );
  });
});
