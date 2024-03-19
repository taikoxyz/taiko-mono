import { getWalletClient } from '@wagmi/core';
import type { WalletClient } from 'viem';
import { any, isA } from 'vitest-mock-extended';

import { routingContractsMap } from '$bridgeConfig';
import { customToken } from '$customToken';
import { estimateCostOfBridging, getMaxAmountToBridge, type GetMaxToBridgeArgs } from '$libs/bridge';
import { ETHBridge } from '$libs/bridge/ETHBridge';
import { ETHToken } from '$libs/token';
import { ALICE, L1_CHAIN_ID, L2_CHAIN_ID } from '$mocks';

vi.mock('$bridgeConfig');
vi.mock('$libs/bridge/estimateCostOfBridging');
vi.mock('@wagmi/core');

vi.mock('$customToken', () => {
  return {
    customToken: [
      {
        name: 'Bull Token',
        addresses: {
          '31336': '0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0',
          '167002': '0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE',
        },
        symbol: 'BLL',
        decimals: 18,
        type: 'ERC20',
        logoURI: 'ipfs://QmezMTpT6ovJ3szb3SKDM9GVGeQ1R8DfjYyXG12ppMe2BY',
      },
    ],
  };
});

const MOCK_FEE = BigInt(2);
const MOCK_BALANCE = BigInt(100);
const MOCK_COST = BigInt(20);

const MOCK_ARGS: GetMaxToBridgeArgs = {
  to: ALICE,
  token: customToken[0],
  balance: MOCK_BALANCE,
  srcChainId: L1_CHAIN_ID,
  destChainId: L2_CHAIN_ID,
  fee: MOCK_FEE,
};

describe('getMaxAmountToBridge()', () => {
  it('should return the whole balance for ERC20 tokens', async () => {
    // Given
    vi.mocked(estimateCostOfBridging).mockResolvedValue(MOCK_COST);

    // When
    const result = await getMaxAmountToBridge(MOCK_ARGS);

    // Then
    expect(result).toBe(BigInt(100));
    expect(estimateCostOfBridging).not.toHaveBeenCalled();
  });

  it('should return the whole balance minus the estimated cost for ETH', async () => {
    // Given
    const expected = MOCK_BALANCE - MOCK_COST - MOCK_FEE;
    const mockClient = {} as WalletClient;

    const args = { ...MOCK_ARGS, token: ETHToken };

    const mockDestBridgeAddress =
      routingContractsMap[Number(MOCK_ARGS.srcChainId)][Number(MOCK_ARGS.destChainId)].bridgeAddress;

    vi.mocked(getWalletClient).mockReturnValue(mockClient);

    vi.mocked(estimateCostOfBridging).mockResolvedValue(MOCK_COST);

    // When
    const result = await getMaxAmountToBridge(args);

    // Then
    expect(result).toBe(expected);
    expect(estimateCostOfBridging).toHaveBeenCalledOnce();
    expect(estimateCostOfBridging).toHaveBeenCalledWith(isA(ETHBridge), {
      to: MOCK_ARGS.to,
      amount: any(),
      wallet: mockClient,
      srcChainId: MOCK_ARGS.srcChainId,
      destChainId: MOCK_ARGS.destChainId,
      bridgeAddress: mockDestBridgeAddress,
      fee: MOCK_FEE,
    });
  });
});
