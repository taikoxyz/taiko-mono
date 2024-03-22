import { getPublicClient } from '@wagmi/core';
import { getContract, zeroAddress } from 'viem';

import { config } from '$libs/wagmi';
import { L1_CHAIN_ID, L2_CHAIN_ID, MOCK_MESSAGE_HASH_1 } from '$mocks';

import { getMessageStatusForMsgHash } from './getMessageStatusForMsgHash';

vi.mock('viem');
vi.mock('@wagmi/core');
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

describe('getMessageStatusForMsgHash', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.resetAllMocks();
  });

  test('should return the message status', async () => {
    // Given
    const expected = 42;
    const msgHash = MOCK_MESSAGE_HASH_1;
    const srcChainId = L1_CHAIN_ID;
    const destChainId = L2_CHAIN_ID;

    const mockClient = {
      request: vi.fn(),
    };

    const mockContract = {
      address: zeroAddress,
      read: {
        messageStatus: vi.fn(),
      },
      abi: [],
    };

    vi.mocked(getPublicClient).mockReturnValue(mockClient);

    vi.mocked(getContract).mockReturnValue(mockContract);

    vi.mocked(getPublicClient).mockReturnValue({});

    mockContract.read.messageStatus.mockResolvedValue(42);

    // When
    const result = await getMessageStatusForMsgHash({ msgHash, srcChainId, destChainId });

    // Then
    expect(result).toEqual(expected);
    expect(getPublicClient).toHaveBeenCalledWith(config, { chainId: destChainId });
  });

  test('should throw an error if public client is not available', async () => {
    // Given
    const msgHash = MOCK_MESSAGE_HASH_1;
    const srcChainId = L1_CHAIN_ID;
    const destChainId = L2_CHAIN_ID;

    // When
    const promise = getMessageStatusForMsgHash({ msgHash, srcChainId, destChainId });

    // Then
    await expect(promise).rejects.toThrow('Could not get public client');
  });
});
