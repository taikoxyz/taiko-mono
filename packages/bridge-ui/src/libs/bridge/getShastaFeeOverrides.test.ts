import { getPublicClient } from '@wagmi/core';
import { parseGwei } from 'viem';

import { isL2Chain } from '$libs/chain';
import { getProtocolVersion, ProtocolVersion } from '$libs/protocol/protocolVersion';

import { calculateExpectedBaseFeePerGas, getShastaFeeOverrides } from './getShastaFeeOverrides';

vi.mock('@wagmi/core', () => ({
  getPublicClient: vi.fn(),
}));

vi.mock('$libs/chain', () => ({
  isL2Chain: vi.fn(),
}));

vi.mock('$libs/protocol/protocolVersion', () => ({
  ProtocolVersion: {
    PACAYA: 'pacaya',
    SHASTA: 'shasta',
  },
  getProtocolVersion: vi.fn(),
}));

vi.mock('$libs/wagmi', () => ({
  config: {},
}));

describe('getShastaFeeOverrides', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it('should clamp calculated base fee to Shasta minimum', () => {
    const result = calculateExpectedBaseFeePerGas({
      parentBaseFeePerGas: 1n,
      parentGasUsed: 0n,
      parentGasLimit: 45_000_000n,
      parentBlockTime: 2n,
    });

    expect(result).toBe(parseGwei('0.005'));
  });

  it('should return undefined for non-L2 chains', async () => {
    vi.mocked(isL2Chain).mockReturnValue(false);

    const result = await getShastaFeeOverrides({
      txChainId: 1,
      srcChainId: 1,
      destChainId: 2,
    });

    expect(result).toBeUndefined();
  });

  it('should return fee overrides for Shasta L2 routes', async () => {
    vi.mocked(isL2Chain).mockReturnValue(true);
    vi.mocked(getProtocolVersion).mockResolvedValue(ProtocolVersion.SHASTA);

    const mockClient = {
      getBlock: vi
        .fn()
        .mockResolvedValueOnce({
          baseFeePerGas: parseGwei('0.005'),
          gasUsed: 1_000_000n,
          gasLimit: 45_000_000n,
          timestamp: 20n,
          parentHash: '0xabc',
        })
        .mockResolvedValueOnce({
          timestamp: 18n,
        }),
      estimateMaxPriorityFeePerGas: vi.fn().mockResolvedValue(1n), // floor should apply
      getGasPrice: vi.fn().mockResolvedValue(parseGwei('0.006')),
    };

    vi.mocked(getPublicClient).mockReturnValue(mockClient);

    const result = await getShastaFeeOverrides({
      txChainId: 167_013,
      srcChainId: 167_013,
      destChainId: 1,
    });

    expect(result).toEqual({
      maxPriorityFeePerGas: parseGwei('0.001'),
      maxFeePerGas: parseGwei('0.011'),
    });
  });

  it('should skip overrides for Pacaya routes', async () => {
    vi.mocked(isL2Chain).mockReturnValue(true);
    vi.mocked(getProtocolVersion).mockResolvedValue(ProtocolVersion.PACAYA);

    const result = await getShastaFeeOverrides({
      txChainId: 167_013,
      srcChainId: 167_013,
      destChainId: 1,
    });

    expect(result).toBeUndefined();
  });
});
