import { readContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { getProofReceiptForMsgHash } from '$libs/bridge/getProofReceiptForMsgHash';
import type { GetProofReceiptParams } from '$libs/bridge/types';
import { config } from '$libs/wagmi';
import { ALICE, MOCK_BRIDGE_TX_1 } from '$mocks';

vi.mock('$libs/bridge/readContract');
vi.mock('$customToken', () => {
  const mockERC20 = {
    name: 'MockERC20',
    addresses: { '1': zeroAddress },
    symbol: 'MTF',
    decimals: 18,
    type: 'ERC20',
  };
  return {
    customToken: [mockERC20],
  };
});

describe('getProofReceiptForMsgHash()', () => {
  const mockArgs = {
    msgHash: MOCK_BRIDGE_TX_1.msgHash,
    destChainId: MOCK_BRIDGE_TX_1.destChainId,
    srcChainId: MOCK_BRIDGE_TX_1.srcChainId,
  } as GetProofReceiptParams;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should call readContract with the correct parameters', async () => {
    const mockDestBridgeAddress =
      routingContractsMap[Number(mockArgs.destChainId)][Number(mockArgs.srcChainId)].bridgeAddress;

    vi.mocked(readContract).mockResolvedValue([0n, ALICE]);

    await getProofReceiptForMsgHash(mockArgs);

    expect(readContract).toHaveBeenCalledWith(config, {
      abi: bridgeAbi,
      address: mockDestBridgeAddress,
      functionName: 'proofReceipt',
      args: [mockArgs.msgHash],
      chainId: Number(mockArgs.destChainId),
    });
  });

  it('should return the result from readContract', async () => {
    const mockResult = [0n, ALICE];

    vi.mocked(readContract).mockResolvedValue(mockResult);

    const result = await getProofReceiptForMsgHash(mockArgs);

    expect(result).toStrictEqual(mockResult);
  });
});
