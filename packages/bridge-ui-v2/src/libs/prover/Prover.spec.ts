import { ethers } from 'ethers'

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public'

import type { Block } from '../block/types'
import { providers } from '../provider'
import { InvalidProofError } from './InvalidProofError'
import { Prover } from './Prover'
import type { EthGetProofResponse } from './types'

vi.mock('$env/static/public')

vi.mock('ethers', async () => {
  const actualEthers = (await vi.importActual('ethers')) as typeof ethers

  const MockContract = vi.fn()
  MockContract.prototype = {
    getXchainBlockHash: vi.fn().mockReturnValue('0x123'),
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

const mockBlock: Block = {
  number: 1,
  hash: '0x123',
  parentHash: '0xa7881266ca0a344c43cb24175d9dbd243b58d45d6ae6ad71310a273a3d1d3afb',
  nonce: 123,
  sha3Uncles: '0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
  logsBloom:
    '0x00000000000400000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000020000000000000000000000000000000000000000000000000100000000008000000000000000000000000',
  transactionsRoot: '0x7273ade6b6ed865a9975ac281da23b90b141a8b607d874d2cd95e65e81336f8e',
  stateRoot: '0xc0dcf937b3f6136dd70a1ad11cc57b040fd410f3c49a5146f20c732895a3cc21',
  receiptsRoot: '0x74bb61e381e9238a08b169580f3cbf9b8b79d7d5ee708d3e286103eb291dfd08',
  miner: '0xea674fdde714fd979de3edf0f56aa9716b898ec8',
  difficulty: 123,
  totalDifficulty: 123,
  extraData: '0x65746865726d696e652d75732d7765737431',
  size: 123,
  gasLimit: 123,
  gasUsed: 123,
  timestamp: 1682596719,
  transactions: [],
  uncles: [],
  baseFeePerGas: '0',
  mixHash: '0xf5ba25df1e92e89a09e0b32063b81795f631100801158f5fa733f2ba26843bd0',
  withdrawalsRoot: ethers.constants.HashZero,
}

const commonProofProps = {
  balance: '',
  nonce: '',
  codeHash: '',
  storageHash: '',
  accountProof: [],
}

const mockClaimableStorageProof: EthGetProofResponse = {
  ...commonProofProps,
  storageProof: [
    {
      key: '0x01',
      value: '0x1',
      proof: [ethers.constants.HashZero],
    },
  ],
}

const mockReleasableStorageProof: EthGetProofResponse = {
  ...commonProofProps,
  storageProof: [
    {
      key: '0x01',
      value: '0x3',
      proof: [ethers.constants.HashZero],
    },
  ],
}

const mockInvalidStorageProof: EthGetProofResponse = {
  ...commonProofProps,
  storageProof: [
    {
      key: '0x01',
      value: '0x0',
      proof: [ethers.constants.HashZero],
    },
  ],
}

const mockProvider = { send: vi.fn() }

providers[PUBLIC_L1_CHAIN_ID] = mockProvider as any
providers[PUBLIC_L2_CHAIN_ID] = mockProvider as any

const expectedProof =
  '0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000380a7881266ca0a344c43cb24175d9dbd243b58d45d6ae6ad71310a273a3d1d3afb1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347000000000000000000000000ea674fdde714fd979de3edf0f56aa9716b898ec8c0dcf937b3f6136dd70a1ad11cc57b040fd410f3c49a5146f20c732895a3cc217273ade6b6ed865a9975ac281da23b90b141a8b607d874d2cd95e65e81336f8e74bb61e381e9238a08b169580f3cbf9b8b79d7d5ee708d3e286103eb291dfd0800000000000400000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000020000000000000000000000000000000000000000000000000100000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000007b0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000007b000000000000000000000000000000000000000000000000000000000000007b00000000000000000000000000000000000000000000000000000000644a636f0000000000000000000000000000000000000000000000000000000000000300f5ba25df1e92e89a09e0b32063b81795f631100801158f5fa733f2ba26843bd0000000000000000000000000000000000000000000000000000000000000007b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001265746865726d696e652d75732d776573743100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022e1a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'

const expectedProofWithBaseFee =
  '0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000380a7881266ca0a344c43cb24175d9dbd243b58d45d6ae6ad71310a273a3d1d3afb1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347000000000000000000000000ea674fdde714fd979de3edf0f56aa9716b898ec8c0dcf937b3f6136dd70a1ad11cc57b040fd410f3c49a5146f20c732895a3cc217273ade6b6ed865a9975ac281da23b90b141a8b607d874d2cd95e65e81336f8e74bb61e381e9238a08b169580f3cbf9b8b79d7d5ee708d3e286103eb291dfd0800000000000400000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000020000000000000000000000000000000000000000000000000100000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000007b0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000007b000000000000000000000000000000000000000000000000000000000000007b00000000000000000000000000000000000000000000000000000000644a636f0000000000000000000000000000000000000000000000000000000000000300f5ba25df1e92e89a09e0b32063b81795f631100801158f5fa733f2ba26843bd0000000000000000000000000000000000000000000000000000000000000007b00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001265746865726d696e652d75732d776573743100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022e1a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'

const eth_getProof = vi.fn()
const eth_getBlockByHash = vi.fn()

describe('Prover', () => {
  beforeAll(() => {
    mockProvider.send.mockImplementation(async (method: string) => {
      switch (method) {
        case 'eth_getProof':
          return eth_getProof()
        case 'eth_getBlockByHash':
          return eth_getBlockByHash()
        default:
          throw Error(`Unexpected method: ${method}`)
      }
    })
  })

  beforeEach(() => {
    eth_getProof.mockReset()
    eth_getBlockByHash.mockReset().mockResolvedValue(mockBlock)
  })

  it('should generate proof to claim tokens', async () => {
    eth_getProof.mockResolvedValue(mockClaimableStorageProof)

    const prover = new Prover(providers)

    const proof = await prover.generateProof({
      msgHash: ethers.constants.HashZero,
      sender: ethers.constants.AddressZero,
      srcChainId: PUBLIC_L1_CHAIN_ID,
      destChainId: PUBLIC_L2_CHAIN_ID,
      destXChainSyncAddress: ethers.constants.AddressZero,
      srcBridgeAddress: ethers.constants.AddressZero,
      srcSignalServiceAddress: ethers.constants.AddressZero,
    })

    expect(proof).toEqual(expectedProof)
  })

  it('should generate proof to claim tokens with baseFeePerGas set', async () => {
    eth_getProof.mockResolvedValue(mockClaimableStorageProof)
    eth_getBlockByHash.mockResolvedValue({ ...mockBlock, baseFeePerGas: '1' })

    const prover = new Prover(providers)

    const proofWithBaseFee = await prover.generateProof({
      msgHash: ethers.constants.HashZero,
      sender: ethers.constants.AddressZero,
      srcChainId: PUBLIC_L1_CHAIN_ID,
      destChainId: PUBLIC_L2_CHAIN_ID,
      destXChainSyncAddress: ethers.constants.AddressZero,
      srcBridgeAddress: ethers.constants.AddressZero,
      srcSignalServiceAddress: ethers.constants.AddressZero,
    })

    expect(proofWithBaseFee).toEqual(expectedProofWithBaseFee)
  })

  it('should throw when generating proof to claim tokens and message status is not 1', async () => {
    eth_getProof.mockResolvedValue(mockInvalidStorageProof)

    const prover = new Prover(providers)

    try {
      await prover.generateProof({
        msgHash: ethers.constants.HashZero,
        sender: ethers.constants.AddressZero,
        srcChainId: PUBLIC_L1_CHAIN_ID,
        destChainId: PUBLIC_L2_CHAIN_ID,
        destXChainSyncAddress: ethers.constants.AddressZero,
        srcBridgeAddress: ethers.constants.AddressZero,
        srcSignalServiceAddress: ethers.constants.AddressZero,
      })
      expect(true).toBe(false) // this should not be reached
    } catch (error) {
      expect(error).toBeInstanceOf(InvalidProofError)
    }
  })

  it('should generate proof to release tokens', async () => {
    eth_getProof.mockResolvedValue(mockReleasableStorageProof)

    const prover = new Prover(providers)

    const proof = await prover.generateReleaseProof({
      msgHash: ethers.constants.HashZero,
      sender: ethers.constants.AddressZero,
      srcChainId: PUBLIC_L2_CHAIN_ID,
      destChainId: PUBLIC_L1_CHAIN_ID,
      destXChainSyncAddress: ethers.constants.AddressZero,
      srcXChainSyncAddress: ethers.constants.AddressZero,
      destBridgeAddress: ethers.constants.AddressZero,
    })

    expect(proof).toEqual(expectedProof)
  })

  it('should generate proof to release tokens with baseFeePerGas set', async () => {
    eth_getProof.mockResolvedValue(mockReleasableStorageProof)
    eth_getBlockByHash.mockResolvedValue({ ...mockBlock, baseFeePerGas: '1' })

    const prover = new Prover(providers)

    const proofWithBaseFee = await prover.generateReleaseProof({
      msgHash: ethers.constants.HashZero,
      sender: ethers.constants.AddressZero,
      srcChainId: PUBLIC_L2_CHAIN_ID,
      destChainId: PUBLIC_L1_CHAIN_ID,
      destXChainSyncAddress: ethers.constants.AddressZero,
      srcXChainSyncAddress: ethers.constants.AddressZero,
      destBridgeAddress: ethers.constants.AddressZero,
    })

    expect(proofWithBaseFee).toEqual(expectedProofWithBaseFee)
  })

  it('should throw when generating proof to release tokens and message status Failed', async () => {
    eth_getProof.mockResolvedValue(mockInvalidStorageProof)

    const prover = new Prover(providers)

    try {
      await prover.generateReleaseProof({
        msgHash: ethers.constants.HashZero,
        sender: ethers.constants.AddressZero,
        srcChainId: PUBLIC_L2_CHAIN_ID,
        destChainId: PUBLIC_L1_CHAIN_ID,
        destXChainSyncAddress: ethers.constants.AddressZero,
        srcXChainSyncAddress: ethers.constants.AddressZero,
        destBridgeAddress: ethers.constants.AddressZero,
      })
      expect(true).toBe(false) // this should not be reached
    } catch (error) {
      expect(error).toBeInstanceOf(InvalidProofError)
    }
  })
})
