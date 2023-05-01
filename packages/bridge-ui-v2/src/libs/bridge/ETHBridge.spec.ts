import { BigNumber, Contract, ethers, type Signer } from 'ethers'

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public'

import { ETHBridge } from './ETHBridge'
import type { ETHBridgeArgs } from './types'

vi.mock('$env/static/public')

vi.mock('ethers', async () => {
  const actualEthers = (await vi.importActual('ethers')) as typeof ethers

  const MockContract = vi.fn()
  MockContract.prototype = {
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

// TODO
describe('ETHBridge', () => {
  beforeEach(() => {
    vi.mocked(Contract.prototype.sendMessage).mockClear()
    vi.mocked(Contract.prototype.estimateGas.sendMessage).mockClear()
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
})
