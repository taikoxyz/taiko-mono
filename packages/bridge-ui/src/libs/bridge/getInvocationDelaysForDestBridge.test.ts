import { readContract } from '@wagmi/core';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { getInvocationDelaysForDestBridge } from '$libs/bridge/getInvocationDelaysForDestBridge';
import { config } from '$libs/wagmi';
import { L1_CHAIN_ID, L2_CHAIN_ID } from '$mocks';

vi.mock('$libs/bridge/readContract');
vi.mock('$customToken', () => {
  const mockERC20 = {
    name: 'MockERC20',
    addresses: { '1': '0x123' },
    symbol: 'MTF',
    decimals: 18,
    type: 'ERC20',
  };
  return {
    customToken: [mockERC20],
  };
});

describe('getInvocationDelaysForDestBridge()', () => {
  it('should return the invocation delays for the bridge', async () => {
    //Given
    vi.mocked(readContract).mockResolvedValue([300, 384]);

    //When
    const result = await getInvocationDelaysForDestBridge({
      srcChainId: BigInt(L1_CHAIN_ID),
      destChainId: BigInt(L2_CHAIN_ID),
    });

    //Then
    expect(result).toStrictEqual([300, 384]);
    expect(readContract).toHaveBeenCalledWith(config, {
      abi: bridgeAbi,
      address: routingContractsMap[L2_CHAIN_ID][L1_CHAIN_ID].bridgeAddress,
      functionName: 'getInvocationDelays',
      chainId: L2_CHAIN_ID,
    });
  });
});
