import { writeContract,type WriteContractParameters } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { config } from '$libs/wagmi';

import { safeWriteContract } from './safeWriteContract';

vi.mock('@wagmi/core');

describe('safeWriteContract', () => {
  it('removes fee fields before submitting tx request', async () => {
    vi.mocked(writeContract).mockResolvedValue('0x1234' as `0x${string}`);

    const params = {
      address: zeroAddress,
      abi: [],
      functionName: 'test',
      maxFeePerGas: 1n,
      maxPriorityFeePerGas: 1n,
      gasPrice: 1n,
      type: 'eip1559',
      gas: 21000n,
    } as unknown as WriteContractParameters;

    await safeWriteContract(params);

    expect(writeContract).toHaveBeenCalledTimes(1);
    expect(writeContract).toHaveBeenCalledWith(
      config,
      expect.objectContaining({
        address: zeroAddress,
        abi: [],
        functionName: 'test',
        gas: 21000n,
      }),
    );

    const submitted = vi.mocked(writeContract).mock.calls[0][1] as Record<string, unknown>;
    expect(submitted.maxFeePerGas).toBeUndefined();
    expect(submitted.maxPriorityFeePerGas).toBeUndefined();
    expect(submitted.gasPrice).toBeUndefined();
    expect(submitted.type).toBeUndefined();
  });
});
