import type { Address } from 'viem';
import { vi } from 'vitest';

const readContract = vi.fn();
vi.mock('@wagmi/core', () => ({
  readContract: (...args: unknown[]) => readContract(...args),
}));
vi.mock('$bridgeConfig', () => ({ routingContractsMap: {} }));
vi.mock('$libs/wagmi', () => ({ config: {} }));

import { isRecallEnabled } from './recallAvailability';

const BRIDGE = '0x0000000000000000000000000000000000000001' as Address;

beforeEach(() => {
  vi.clearAllMocks();
});

it('reads recallEnabled from the requested bridge', async () => {
  readContract.mockResolvedValue(false);

  await expect(isRecallEnabled(167, BRIDGE)).resolves.toBe(false);
  expect(readContract).toHaveBeenCalledWith(
    expect.anything(),
    expect.objectContaining({
      address: BRIDGE,
      chainId: 167,
      functionName: 'recallEnabled',
    }),
  );
});

it('fails closed when recall availability cannot be read', async () => {
  readContract.mockRejectedValue(new Error('RPC unavailable'));

  await expect(isRecallEnabled(167, BRIDGE)).resolves.toBe(false);
});
