import { BigNumber, Contract, ethers, type Signer } from 'ethers'

import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public'

import { ETHBridge } from './ETHBridge'
import type { ETHBridgeArgs } from './types'

vi.mock('$env/static/public')

vi.mock('ethers', async () => {
  const actualEthers = (await vi.importActual('ethers')) as typeof ethers

  const MockContract = vi.fn()
  MockContract.prototype = {
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
  it('should estimate gas to bridge ETH', async () => {
    const gasEstimate = await ETHBridge.estimateGas(mockArgs)

    expect(gasEstimate).toEqual(10)

    const mockedSendMessage = vi.mocked(Contract.prototype.estimateGas.sendMessage)
    expect(mockedSendMessage).toHaveBeenCalledWith(
      {
        sender: '0x123',
        srcChainId: PUBLIC_L1_CHAIN_ID,
        destChainId: PUBLIC_L2_CHAIN_ID,
        owner: '0x123',
        to: '0x123',
        refundAddress: '0x123',
        depositValue: BigNumber.from(123),
        callValue: BigNumber.from(0),
        processingFee: BigNumber.from(123),
        gasLimit: BigNumber.from(140000),
        memo: '',
        id: 1,
        data: '0x',
      },
      {
        value: BigNumber.from(123).add(BigNumber.from(123)).add(BigNumber.from(0)),
      },
    )
  })
})
