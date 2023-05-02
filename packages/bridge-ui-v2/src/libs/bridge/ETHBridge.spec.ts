import { BigNumber, Contract, ethers, type Signer } from 'ethers'

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public'

import { chains } from '../chain'
import { MessageOwnerError } from '../message/MessageOwnerError'
import { MessageStatusError } from '../message/MessageStatusError'
import { type Message, MessageStatus } from '../message/types'
import { Prover } from '../prover'
import { providers } from '../provider'
import { ETHBridge } from './ETHBridge'
import type { ClaimArgs, ETHBridgeArgs } from './types'

vi.mock('$env/static/public')

vi.mock('ethers', async () => {
  const actualEthers = (await vi.importActual('ethers')) as typeof ethers

  const MockContract = vi.fn()
  MockContract.prototype = {
    getMessageStatus: vi.fn(),
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

const mockChain = {}

chains[PUBLIC_L1_CHAIN_ID] = mockChain as any
chains[PUBLIC_L2_CHAIN_ID] = mockChain as any

// TODO
describe('ETHBridge', () => {
  beforeEach(() => {
    vi.mocked(Contract.prototype.sendMessage).mockClear()
    vi.mocked(Contract.prototype.estimateGas.sendMessage).mockClear()
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(() => MessageStatus.New)
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
    }
  })

  it('should fail claiming if the message status is Done', async () => {
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(() => MessageStatus.Done)

    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    try {
      await bridge.claim(mockClaimArgs)
      expect(true).toBeFalsy()
    } catch (error) {
      expect(error).instanceOf(MessageStatusError)
    }
  })

  it('should fail claiming if the message status is Failed', async () => {
    vi.mocked(Contract.prototype.getMessageStatus).mockResolvedValue(() => MessageStatus.Failed)

    const prover = new Prover(providers)
    const bridge = new ETHBridge(prover, chains)

    try {
      await bridge.claim(mockClaimArgs)
      expect(true).toBeFalsy()
    } catch (error) {
      expect(error).instanceOf(MessageStatusError)
    }
  })
})
