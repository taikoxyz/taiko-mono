import { readContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { safeReadContract } from './safeReadContract';

vi.mock('@wagmi/core');

describe('safeReadContract', () => {
  it('should return contract data on success', async () => {
    const mockData = { data: 'mockData' };
    vi.mocked(readContract).mockResolvedValue(mockData);

    const result = await safeReadContract({
      address: zeroAddress,
      abi: [],
      functionName: 'functionName',
      chainId: 1,
    });

    expect(result).toEqual(mockData);
  });

  it('should return null on failure', async () => {
    vi.mocked(readContract).mockRejectedValue(new Error('mockError'));

    const result = await safeReadContract({
      address: zeroAddress,
      abi: [],
      functionName: 'functionName',
      chainId: 1,
    });

    expect(result).toBeNull();
  });
});
