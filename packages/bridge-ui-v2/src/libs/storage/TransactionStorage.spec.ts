import type { ethers } from 'ethers'
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public'

import { chains } from '../chain'
import { MessageStatus } from '../message/types'
import { providers } from '../provider'
import type { BridgeTransaction } from '../transaction/types'
import { tokenVaults } from '../vault'
import { TransactionStorage } from './TransactionStorage'

var mockProvider = {
  getTransactionReceipt: vi.fn(),
  waitForTransaction: vi.fn(),
}

vi.mock('../provider', () => ({
  providers: {
    [PUBLIC_L1_CHAIN_ID]: mockProvider as any,
    [PUBLIC_L2_CHAIN_ID]: mockProvider as any,
  },
}))

var mockContract = {
  queryFilter: vi.fn(),
  getMessageStatus: vi.fn(),
  symbol: vi.fn(),
  filters: {
    // Returns this string to help us
    // identify the filter in the tests
    ERC20Sent: () => 'ERC20Sent',
  },
}

vi.mock('ethers', async () => {
  const ethersModule = await vi.importActual<typeof ethers>('ethers')

  class Contract {
    constructor() {
      return mockContract
    }
  }

  return {
    ...ethersModule,
    Contract,
  }
})

const mockStorage = {
  getItem: vi.fn(),
  setItem: vi.fn(),
}

const mockTx: BridgeTransaction = {
  hash: '0xABC',
  from: '0x123',
  status: MessageStatus.New,
  fromChainId: PUBLIC_L1_CHAIN_ID,
  toChainId: PUBLIC_L2_CHAIN_ID,
}

const mockTxs: BridgeTransaction[] = [mockTx]

const mockTxReceipt = { blockNumber: 1 }

const mockEvent = {
  args: {
    message: { owner: '0x234' },
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
  beforeAll(() => {
    mockProvider.waitForTransaction.mockImplementation(() => {
      return Promise.resolve(mockTxReceipt)
    })

    mockContract.getMessageStatus.mockImplementation(() => {
      return MessageStatus.New
    })
  })

  beforeEach(() => {
    mockStorage.getItem.mockImplementation(() => {
      return JSON.stringify(mockTxs)
    })

    mockProvider.getTransactionReceipt.mockImplementation(() => {
      return mockTxReceipt
    })

    mockContract.queryFilter.mockReset()
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

    const txs = await txStorage.getAllByAddress('0x666')

    expect(txs).toEqual([])
  })

  // it('gets all transactions by address, no transactions in list', async () => {
  //   mockStorage.getItem.mockImplementation(() => {
  //     return '[]'
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const txs = await svc.getAllByAddress('0x123')

  //   expect(txs).toEqual([])
  // })

  // it('gets all transactions by address, no receipt', async () => {
  //   mockProvider.getTransactionReceipt.mockImplementation(() => {
  //     return null
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const txs = await svc.getAllByAddress('0x123')

  //   expect(txs).toEqual([mockTx])
  // })

  // it('gets all transactions by address, no MessageSent event', async () => {
  //   mockContract.queryFilter.mockImplementation(() => {
  //     return []
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const txs = await svc.getAllByAddress('0x123')

  //   expect(txs).toEqual([
  //     {
  //       ...mockTx,
  //       receipt: { blockNumber: 1 },
  //     },
  //   ])
  // })

  // it('gets all transactions by address, ETH transfer', async () => {
  //   mockContract.queryFilter.mockImplementation(() => {
  //     return mockQuery
  //   })

  //   mockContract.symbol.mockImplementation(() => {
  //     return 'ETH'
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const txs = await svc.getAllByAddress('0x123')

  //   expect(txs).toEqual([
  //     {
  //       ...mockTx,
  //       receipt: { blockNumber: 1 },
  //       msgHash: mockEvent.args.msgHash,
  //       message: mockEvent.args.message,
  //     },
  //   ])
  // })

  // it('gets all transactions by address, no ERC20Sent event', async () => {
  //   mockContract.queryFilter.mockImplementation((filter: string) => {
  //     if (filter === 'ERC20Sent') return []
  //     return mockErc20Query // MessageSent
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const txs = await svc.getAllByAddress('0x123')

  //   // There is no symbol nor amountInWei
  //   expect(txs).toEqual([
  //     {
  //       ...mockTx,
  //       receipt: { blockNumber: 1 },
  //       msgHash: mockErc20Event.args.msgHash,
  //       message: mockErc20Event.args.message,
  //     },
  //   ])
  // })

  // it('gets all transactions by address, ERC20 transfer', async () => {
  //   mockContract.queryFilter.mockImplementation(() => {
  //     return mockErc20Query
  //   })

  //   mockContract.symbol.mockImplementation(() => {
  //     return TKOToken.symbol
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const txs = await svc.getAllByAddress('0x123')

  //   expect(txs).toEqual([
  //     {
  //       ...mockTx,
  //       receipt: {
  //         blockNumber: 1,
  //       },
  //       msgHash: mockErc20Event.args.msgHash,
  //       message: mockErc20Event.args.message,

  //       // We should have these two
  //       symbol: TKOToken.symbol,
  //       amountInWei: BigNumber.from(0x64),
  //     },
  //   ])
  // })

  // it('ignore txs from unsupported chains when getting all txs', async () => {
  //   providers[L1_CHAIN_ID] = undefined

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const txs = await svc.getAllByAddress('0x123')

  //   expect(txs).toEqual([])
  // })

  // it('handles invalid JSON when getting transaction by hash', async () => {
  //   mockStorage.getItem.mockImplementation(() => {
  //     return 'invalid json'
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const tx = await svc.getTransactionByHash('0x123', mockTx.hash)

  //   expect(tx).toBeUndefined()
  // })

  // it('get transaction by hash, no receipt', async () => {
  //   mockProvider.getTransactionReceipt.mockImplementation(() => {
  //     return null
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const tx = await svc.getTransactionByHash('0x123', mockTx.hash)

  //   expect(tx).toEqual(tx)
  // })

  // it('get transaction by hash, no event', async () => {
  //   mockContract.queryFilter.mockImplementation(() => {
  //     return []
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const tx = await svc.getTransactionByHash('0x123', mockTx.hash)

  //   expect(tx).toEqual({
  //     ...tx,
  //     receipt: { blockNumber: 1 },
  //   })
  // })

  // it('get transaction by hash where tx.from !== address', async () => {
  //   const svc = new StorageService(mockStorage as any, providers)

  //   const tx = await svc.getTransactionByHash('0x666', mockTx.hash)

  //   expect(tx).toBeUndefined()
  // })

  // it('get transaction by hash, ETH transfer', async () => {
  //   mockContract.queryFilter.mockImplementation(() => {
  //     return mockQuery
  //   })

  //   mockContract.symbol.mockImplementation(() => {
  //     return 'ETH'
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const tx = await svc.getTransactionByHash('0x123', mockTx.hash)

  //   expect(tx).toEqual({
  //     ...mockTx,
  //     message: mockEvent.args.message,
  //     receipt: { blockNumber: 1 },
  //     msgHash: mockEvent.args.msgHash,
  //     status: 0,
  //   })
  // })

  // it('get transaction by hash, no ERC20Sent event', async () => {
  //   mockContract.queryFilter.mockImplementation((filter: string) => {
  //     if (filter === 'ERC20Sent') return []
  //     return mockErc20Query // MessageSent
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const tx = await svc.getTransactionByHash('0x123', mockTx.hash)

  //   // There is no symbol nor amountInWei
  //   expect(tx).toEqual({
  //     ...mockTx,
  //     receipt: { blockNumber: 1 },
  //     msgHash: mockErc20Event.args.msgHash,
  //     message: mockErc20Event.args.message,
  //   })
  // })

  // it('get transaction by hash, ERC20 transfer', async () => {
  //   mockContract.queryFilter.mockImplementation(() => {
  //     return mockErc20Query
  //   })

  //   mockContract.symbol.mockImplementation(() => {
  //     return TKOToken.symbol
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const tx = await svc.getTransactionByHash('0x123', mockTx.hash)

  //   expect(tx).toEqual({
  //     ...mockTx,
  //     amountInWei: BigNumber.from(0x64),
  //     message: mockErc20Event.args.message,
  //     receipt: {
  //       blockNumber: 1,
  //     },
  //     msgHash: mockErc20Event.args.msgHash,
  //     status: 0,
  //     symbol: TKOToken.symbol,
  //   })
  // })

  // it('ignore txs from unsupported chains when getting txs by hash', async () => {
  //   providers[L1_CHAIN_ID] = undefined

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const tx = await svc.getTransactionByHash('0x123', mockTx.hash)

  //   expect(tx).toBeUndefined()
  // })

  // it('updates storage by address', () => {
  //   mockStorage.getItem.mockImplementation(() => {
  //     return JSON.stringify(mockTxs)
  //   })

  //   const svc = new StorageService(mockStorage as any, providers)

  //   const newTx = { ...mockTx } as BridgeTransaction
  //   newTx.status = MessageStatus.Done

  //   svc.updateStorageByAddress('0x123', [newTx])

  //   expect(mockStorage.setItem).toHaveBeenCalledWith('transactions-0x123', JSON.stringify([newTx]))
  // })
})
