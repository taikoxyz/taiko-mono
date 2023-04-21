import { ethers } from 'ethers'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public'

import { chains } from '../chain'
import { MessageStatus } from '../message/types'
import { providers } from '../provider'
import type { BridgeTransaction } from '../transaction/types'
import { tokenVaults } from '../vault'
import { TransactionStorage } from './TransactionStorage'

vi.mock('$env/static/public')

vi.mock('ethers', async () => {
  const actualEthers = (await vi.importActual('ethers')) as any

  const MockContract = vi.fn()
  MockContract.prototype = {
    symbol: vi.fn(),
    queryFilter: vi.fn(),
    getMessageStatus: vi.fn().mockImplementation(() => Promise.resolve(MessageStatus.New)),
    filters: {
      // Returns this string to help us
      // identify the filter in the tests
      ERC20Sent: vi.fn().mockReturnValue('ERC20Sent'),
    },
  }

  const mockEthers = {
    ...actualEthers,
    Contract: MockContract,
  }

  return {
    ...mockEthers,
    ethers: mockEthers,
  }
})

const mockTx: BridgeTransaction = {
  hash: '0xABC',
  from: '0x123',
  status: MessageStatus.New,
  fromChainId: PUBLIC_L1_CHAIN_ID,
  toChainId: PUBLIC_L2_CHAIN_ID,
}

const mockTxs: BridgeTransaction[] = [mockTx]

const mockStorage = {
  getItem: vi.fn(),
  setItem: vi.fn(),
}

const mockTxReceipt = { blockNumber: 1 }

const mockProvider = {
  getTransactionReceipt: vi.fn(),
  waitForTransaction: vi.fn().mockResolvedValue(null),
}

providers[PUBLIC_L1_CHAIN_ID] = mockProvider as any
providers[PUBLIC_L2_CHAIN_ID] = mockProvider as any

const mockEvent = {
  args: {
    message: { owner: '0x123' },
    msgHash: '0xBCD',
    amount: '100',
  },
}

const mockErc20Event = {
  args: {
    amount: '100',
    msgHash: '0xCDE',
    message: {
      owner: '0x123',
      data: '0x789',
    },
  },
}

const mockQuery = [mockEvent]

const mockErc20Query = [mockErc20Event]

describe('storage tests', () => {
  beforeEach(() => {
    mockStorage.getItem.mockReturnValue(JSON.stringify(mockTxs))

    mockProvider.getTransactionReceipt.mockResolvedValue(mockTxReceipt)

    vi.mocked(ethers.Contract.prototype.queryFilter).mockReset()

    vi.mocked(ethers.Contract.prototype.symbol).mockReset()
  })

  it('handles invalid JSON when getting all transactions', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return 'invalid json'
    })

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const txs = await txStorage.getAllByAddress('0x123')

    expect(txs).toEqual([])
  })

  it('gets all transactions by address where tx.from !== address', async () => {
    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const txs = await txStorage.getAllByAddress('0x666') // 0x666 !== mockTx.from

    expect(txs).toEqual([])
  })

  it('gets all transactions by address, no transactions in list', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return '[]'
    })

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const txs = await txStorage.getAllByAddress('0x123')

    expect(txs).toEqual([])
  })

  it('gets all transactions by address, no receipt', async () => {
    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return null
    })

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const txs = await txStorage.getAllByAddress('0x123')

    expect(txs).toEqual([mockTx])
  })

  it('gets all transactions by address, no MessageSent event', async () => {
    vi.mocked(ethers.Contract.prototype.queryFilter).mockResolvedValue([])

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const txs = await txStorage.getAllByAddress('0x123')

    expect(txs).toEqual([
      {
        ...mockTx,
        receipt: { blockNumber: 1 },
      },
    ])
  })

  it('gets all transactions by address, ETH transfer', async () => {
    vi.mocked(ethers.Contract.prototype.queryFilter).mockResolvedValue(mockQuery as any)
    vi.mocked(ethers.Contract.prototype.symbol).mockResolvedValue('ETH')

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const txs = await txStorage.getAllByAddress('0x123')

    expect(txs).toEqual([
      {
        ...mockTx,
        receipt: { blockNumber: 1 },
        msgHash: mockEvent.args.msgHash,
        message: mockEvent.args.message,
      },
    ])
  })

  it('gets all transactions by address, no ERC20Sent event', async () => {
    vi.mocked(ethers.Contract.prototype.queryFilter).mockImplementation(
      (event: ethers.ContractEventName): any => {
        if (event === 'ERC20Sent') return []
        return mockErc20Query // MessageSent
      },
    )

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const txs = await txStorage.getAllByAddress('0x123')

    // There is no symbol nor amountInWei
    expect(txs).toEqual([
      {
        ...mockTx,
        receipt: { blockNumber: 1 },
        msgHash: mockErc20Event.args.msgHash,
        message: mockErc20Event.args.message,
      },
    ])
  })

  it('gets all transactions by address, ERC20 transfer', async () => {
    vi.mocked(ethers.Contract.prototype.queryFilter).mockResolvedValue(mockErc20Query as any)
    vi.mocked(ethers.Contract.prototype.symbol).mockResolvedValue('TKO')

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const txs = await txStorage.getAllByAddress('0x123')

    expect(txs).toEqual([
      {
        ...mockTx,
        receipt: {
          blockNumber: 1,
        },
        msgHash: mockErc20Event.args.msgHash,
        message: mockErc20Event.args.message,

        // We should have these two
        symbol: 'TKO',
        amountInWei: BigInt(100),
      },
    ])
  })

  it('ignores txs from unsupported chains when getting all txs', async () => {
    providers[PUBLIC_L1_CHAIN_ID] = undefined as any

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const txs = await txStorage.getAllByAddress('0x123')

    expect(txs).toEqual([])

    // Let's put it back
    providers[PUBLIC_L1_CHAIN_ID] = mockProvider as any
  })

  it('handles invalid JSON when getting transaction by hash', async () => {
    mockStorage.getItem.mockImplementation(() => {
      return 'invalid json'
    })

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const tx = await txStorage.getTransactionByHash('0x123', mockTx.hash)

    expect(tx).toBeUndefined()
  })

  it('get transaction by hash, no receipt', async () => {
    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return null
    })

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const tx = await txStorage.getTransactionByHash('0x123', mockTx.hash)

    expect(tx).toEqual(tx)
  })

  it('get transaction by hash, no event', async () => {
    vi.mocked(ethers.Contract.prototype.queryFilter).mockResolvedValue([])

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const tx = await txStorage.getTransactionByHash('0x123', mockTx.hash)

    expect(tx).toEqual({
      ...tx,
      receipt: { blockNumber: 1 },
    })
  })

  it('get transaction by hash where tx.from !== address', async () => {
    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const tx = await txStorage.getTransactionByHash('0x666', mockTx.hash)

    expect(tx).toBeUndefined()
  })

  it('get transaction by hash, ETH transfer', async () => {
    vi.mocked(ethers.Contract.prototype.queryFilter).mockResolvedValue(mockQuery as any)
    vi.mocked(ethers.Contract.prototype.symbol).mockResolvedValue('ETH')

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const tx = await txStorage.getTransactionByHash('0x123', mockTx.hash)

    expect(tx).toEqual({
      ...mockTx,
      message: mockEvent.args.message,
      receipt: { blockNumber: 1 },
      msgHash: mockEvent.args.msgHash,
      status: MessageStatus.New,
    })
  })

  it('get transaction by hash, no ERC20Sent event', async () => {
    vi.mocked(ethers.Contract.prototype.queryFilter).mockImplementation(
      (event: ethers.ContractEventName): any => {
        if (event === 'ERC20Sent') return []
        return mockErc20Query // MessageSent
      },
    )

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const tx = await txStorage.getTransactionByHash('0x123', mockTx.hash)

    // There is no symbol nor amountInWei
    expect(tx).toEqual({
      ...mockTx,
      receipt: { blockNumber: 1 },
      msgHash: mockErc20Event.args.msgHash,
      message: mockErc20Event.args.message,
    })
  })

  it('get transaction by hash, ERC20 transfer', async () => {
    vi.mocked(ethers.Contract.prototype.queryFilter).mockResolvedValue(mockErc20Query as any)
    vi.mocked(ethers.Contract.prototype.symbol).mockResolvedValue('TKO')

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const tx = await txStorage.getTransactionByHash('0x123', mockTx.hash)

    expect(tx).toEqual({
      ...mockTx,
      amountInWei: BigInt(100),
      message: mockErc20Event.args.message,
      receipt: {
        blockNumber: 1,
      },
      msgHash: mockErc20Event.args.msgHash,
      status: 0,
      symbol: 'TKO',
    })
  })

  it('ignore txs from unsupported chains when getting txs by hash', async () => {
    providers[PUBLIC_L1_CHAIN_ID] = undefined as any

    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const tx = await txStorage.getTransactionByHash('0x123', mockTx.hash)

    expect(tx).toBeUndefined()
  })

  it('updates storage by address', () => {
    const txStorage = new TransactionStorage(mockStorage as any, providers, chains, tokenVaults)

    const newTx = { ...mockTx } as BridgeTransaction
    newTx.status = MessageStatus.Done

    txStorage.updateStorageByAddress('0x123', [newTx])

    expect(mockStorage.setItem).toHaveBeenCalledWith('transactions-0x123', JSON.stringify([newTx]))
  })
})
