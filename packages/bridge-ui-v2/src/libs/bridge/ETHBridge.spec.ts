import { BigNumber, Contract, ethers, type Signer, type Transaction } from 'ethers'

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public'

import { chains } from '../chain'
import { MessageOwnerError, MessageOwnerErrorCause } from '../message/MessageOwnerError'
import { MessageStatusError, MessageStatusErrorCause } from '../message/MessageStatusError'
import { type Message, MessageStatus } from '../message/types'
import { Prover } from '../prover'
import { providers } from '../provider'
import { ETHBridge } from './ETHBridge'
import type { ClaimArgs, ETHBridgeArgs, ReleaseArgs } from './types'

vi.mock('$env/static/public')

vi.mock('ethers', async () => {
  const actualEthers = (await vi.importActual('ethers')) as typeof ethers

  const MockContract = vi.fn()
  MockContract.prototype = {
    getMessageStatus: vi.fn(),
    processMessage: vi.fn(),
    releaseEther: vi.fn(),
    sendMessage: vi.fn(),
    estimateGas: {
      sendMessage: vi.fn().mockResolvedValue(10),
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

const mockSigner = {
  getAddress: vi.fn().mockResolvedValue('0x123'),
} as unknown as Signer

const mockArgs: ETHBridgeArgs = {
  to: '0x123',
  signer: mockSigner,
  srcChainId: PUBLIC_L1_CHAIN_ID,
  destChainId: PUBLIC_L2_CHAIN_ID,
  amountInWei: BigNumber.from(123),
  processingFeeInWei: BigNumber.from(123),
  bridgeAddress: '0x123',
}

const mockMessage: Message = {
  id: 123,
  sender: '0x123',
  srcChainId: PUBLIC_L1_CHAIN_ID,
  destChainId: PUBLIC_L2_CHAIN_ID,
  owner: '0x123',
  to: '0x123',
  refundAddress: '0x123',
  depositValue: BigNumber.from(123),
  callValue: BigNumber.from(0),
  processingFee: BigNumber.from(123),
  gasLimit: BigNumber.from(123),
  memo: '',
}

const mockClaimArgs: ClaimArgs = {
  message: mockMessage,
  msgHash: '0x123',
  signer: mockSigner,
  destBridgeAddress: '0x123',
  srcBridgeAddress: '0x345',
}

const mockProvider = { send: vi.fn() }

providers[PUBLIC_L1_CHAIN_ID] = mockProvider as any
providers[PUBLIC_L2_CHAIN_ID] = mockProvider as any

const mockReleaseArgs: ReleaseArgs = {
  ...mockClaimArgs,
  destProvider: mockProvider as any,
  srcTokenVaultAddress: '0x123',
}

const mockChain = {
  xChainSyncAddress: '0x123',
  signalServiceAddress: '0x123',
}

chains[PUBLIC_L1_CHAIN_ID] = mockChain as any
chains[PUBLIC_L2_CHAIN_ID] = mockChain as any

const mockProof = '0x123'

const mockTransaction: Transaction = {
  nonce: 123,
  gasLimit: BigNumber.from(123),
  data: '',
  value: BigNumber.from(123),
  chainId: 123,
}

// TODO
describe('ETHBridge', () => {
  beforeAll(() => {
    Prover.prototype.generateProof = vi.fn().mockResolvedValue(mockProof)
    Prover.prototype.generateReleaseProof = vi.fn().mockResolvedValue(mockProof)
    vi.mocked(Contract.prototype.processMessage).mockResolvedValue(mockTransaction)
    vi.mocked(Contract.prototype.releaseEther).mockResolvedValue(mockTransaction)
  })

  beforeEach(() => {
    vi.mocked(Prover.prototype.generateProof).mockClear()
    vi.mocked(Prover.prototype.generateReleaseProof).mockClear()
    vi.mocked(Contract.prototype.sendMessage).mockClear()
    vi.mocked(Contract.prototype.estimateGas.sendMessage).mockClear()
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(MessageStatus.New)
  })

  it('should estimate gas to bridge ETH', async () => {
    const gasEstimate = await ETHBridge.estimateGas(mockArgs)

    // This test is not that important but we make sure
    // that the fake gas estimate is at least getting returned
    expect(gasEstimate).toEqual(10)

    const mockedEstimateGasSendMessage = vi.mocked(Contract.prototype.estimateGas.sendMessage)

    const depositValue = BigNumber.from(123)
    const callValue = BigNumber.from(0)
    const processingFee = BigNumber.from(123)
    const gasLimit = BigNumber.from(140000)

    expect(mockedEstimateGasSendMessage).toHaveBeenCalledWith(
      {
        sender: '0x123',
        srcChainId: PUBLIC_L1_CHAIN_ID,
        destChainId: PUBLIC_L2_CHAIN_ID,
        owner: '0x123',
        to: '0x123',
        refundAddress: '0x123',
        depositValue,
        callValue,
        processingFee,
        gasLimit,
        memo: '',
        id: 1,
        data: '0x',
      },
      {
        value: depositValue.add(processingFee).add(callValue),
      },
    )
  })

  it('should bridge ETH', async () => {
    // Let's make some changes here to execute other branches
    const mockedArgsWithDifferentToAddress = {
      ...mockArgs,

      to: '0x321', // to !== owner address
      // then:
      // depositValue: BigNumber.from(0)
      // callValue: amountInWei

      processingFeeInWei: undefined,
      // then:
      // processingFee: BigNumber.from(0)
      // gasLimit: BigNumber.from(0)

      memo: 'This is a test',
    }

    await ETHBridge.bridge(mockedArgsWithDifferentToAddress)

    const mockedSendMessage = vi.mocked(Contract.prototype.sendMessage)

    const depositValue = BigNumber.from(0)
    const callValue = BigNumber.from(123)
    const processingFee = BigNumber.from(0)
    const gasLimit = BigNumber.from(0)

    expect(mockedSendMessage).toHaveBeenCalledWith(
      {
        sender: '0x123',
        srcChainId: PUBLIC_L1_CHAIN_ID,
        destChainId: PUBLIC_L2_CHAIN_ID,
        owner: '0x123',
        to: '0x321',
        refundAddress: '0x123',
        depositValue,
        callValue,
        processingFee,
        gasLimit,
        memo: 'This is a test',
        id: 1,
        data: '0x',
      },
      {
        value: depositValue.add(processingFee).add(callValue),
      },
    )
  })

  it('should fail claiming if not the owner of the message', async () => {
    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    const mockClaimArgsWithDifferentOwner = {
      ...mockClaimArgs,
      message: {
        ...mockClaimArgs.message,
        owner: '0x321', // different from signer address 0x123
      },
    }

    try {
      await bridge.claim(mockClaimArgsWithDifferentOwner)
      expect(true).toBe(false) // should not reach here
    } catch (error) {
      expect(error).instanceOf(MessageOwnerError)
      expect(error).toHaveProperty('cause', MessageOwnerErrorCause.NO_MESSAGE_OWNER)
    }
  })

  it('should fail claiming if the message status is Done', async () => {
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(MessageStatus.Done)

    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    try {
      await bridge.claim(mockClaimArgs)
      expect(true).toBeFalsy()
    } catch (error) {
      expect(error).instanceOf(MessageStatusError)
      expect(error).toHaveProperty('cause', MessageStatusErrorCause.MESSAGE_ALREADY_PROCESSED)
    }
  })

  it('should fail claiming if the message status is Failed', async () => {
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(MessageStatus.Failed)

    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    try {
      await bridge.claim(mockClaimArgs)
      expect(true).toBeFalsy()
    } catch (error) {
      expect(error).instanceOf(MessageStatusError)
      expect(error).toHaveProperty('cause', MessageStatusErrorCause.MESSAGE_ALREADY_FAILED)
    }
  })

  it('should claim ETH', async () => {
    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    const tx = await bridge.claim(mockClaimArgs)

    // Did it return the transaction? (no error occurred)
    expect(tx).toEqual(mockTransaction)

    // Did it call the right methods with the right arguments?

    const mockedGenerateProof = vi.mocked(Prover.prototype.generateProof)
    expect(mockedGenerateProof).toHaveBeenCalledWith({
      msgHash: mockClaimArgs.msgHash,
      sender: mockClaimArgs.srcBridgeAddress,
      srcChainId: mockClaimArgs.message.srcChainId,
      destChainId: mockClaimArgs.message.destChainId,
      srcBridgeAddress: mockClaimArgs.srcBridgeAddress,
      destXChainSyncAddress: mockChain.xChainSyncAddress,
      srcSignalServiceAddress: mockChain.signalServiceAddress,
    })

    const mockedProcessMessage = vi.mocked(Contract.prototype.processMessage)
    expect(mockedProcessMessage).toHaveBeenCalledWith(mockClaimArgs.message, mockProof)
  })

  it('should fail claiming if the message status is something else', async () => {
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(999)

    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    try {
      await bridge.claim(mockClaimArgs)
      expect(true).toBeFalsy()
    } catch (error) {
      expect(error).instanceOf(MessageStatusError)
      expect(error).toHaveProperty('cause', MessageStatusErrorCause.UNEXPECTED_MESSAGE_STATUS)
    }
  })

  it('should fail releasing if not the owner of the message', async () => {
    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    const mockReleaseArgsWithDifferentOwner = {
      ...mockReleaseArgs,
      message: {
        ...mockClaimArgs.message,
        owner: '0x321', // different from signer address 0x123
      },
    }

    try {
      await bridge.release(mockReleaseArgsWithDifferentOwner)
      expect(true).toBeFalsy()
    } catch (error) {
      expect(error).instanceOf(MessageOwnerError)
      expect(error).toHaveProperty('cause', MessageOwnerErrorCause.NO_MESSAGE_OWNER)
    }
  })

  it('should fail releasing if the message status is Done', async () => {
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(MessageStatus.Done)

    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    try {
      await bridge.claim(mockReleaseArgs)
      expect(true).toBeFalsy()
    } catch (error) {
      expect(error).instanceOf(MessageStatusError)
      expect(error).toHaveProperty('cause', MessageStatusErrorCause.MESSAGE_ALREADY_PROCESSED)
    }
  })

  it('should release ETH', async () => {
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(MessageStatus.Failed)

    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    const tx = await bridge.release(mockReleaseArgs)

    // Did it return the transaction? (no error occurred)
    expect(tx).toEqual(mockTransaction)

    // Did it call the right methods with the right arguments?

    const mockedGenerateReleaseProof = vi.mocked(Prover.prototype.generateReleaseProof)
    expect(mockedGenerateReleaseProof).toHaveBeenCalledWith({
      srcChainId: mockReleaseArgs.message.srcChainId,
      destChainId: mockReleaseArgs.message.destChainId,
      msgHash: mockReleaseArgs.msgHash,
      sender: mockReleaseArgs.srcBridgeAddress,
      destBridgeAddress: mockReleaseArgs.destBridgeAddress,
      destXChainSyncAddress: mockChain.xChainSyncAddress,
      srcXChainSyncAddress: mockChain.xChainSyncAddress,
    })

    const mockedReleaseEther = vi.mocked(Contract.prototype.releaseEther)
    expect(mockedReleaseEther).toHaveBeenCalledWith(mockReleaseArgs.message, mockProof)
  })

  it('should fail releasing if the message status is something else', async () => {
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(999)

    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    try {
      await bridge.release(mockReleaseArgs)
      expect(true).toBeFalsy()
    } catch (error) {
      expect(error).instanceOf(MessageStatusError)
      expect(error).toHaveProperty('cause', MessageStatusErrorCause.UNEXPECTED_MESSAGE_STATUS)
    }
  })
})
