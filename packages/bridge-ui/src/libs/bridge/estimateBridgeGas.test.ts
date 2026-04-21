import { estimateBridgeGasOrFallback } from './estimateBridgeGas';

describe('estimateBridgeGasOrFallback', () => {
  const fallback = 500_000;

  beforeEach(() => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns the estimated gas when estimation succeeds', async () => {
    const estimated = 1_234_567n;
    const result = await estimateBridgeGasOrFallback(async () => estimated, fallback);

    expect(result).toBe(estimated);
    expect(console.error).not.toHaveBeenCalled();
  });

  it('returns the supplied fallback gas when estimation rejects', async () => {
    const result = await estimateBridgeGasOrFallback(async () => {
      throw new Error('RPC rejected eth_estimateGas');
    }, fallback);

    expect(result).toBe(BigInt(fallback));
    expect(console.error).toHaveBeenCalledWith(
      'Failed to estimate gas for bridge tx, using fallback',
      expect.any(Error),
    );
  });

  it('falls back on non-Error rejections', async () => {
    const result = await estimateBridgeGasOrFallback(async () => {
      // eslint-disable-next-line @typescript-eslint/only-throw-error
      throw 'network down';
    }, fallback);

    expect(result).toBe(BigInt(fallback));
    expect(console.error).toHaveBeenCalled();
  });

  it('coerces a numeric fallback to a bigint', async () => {
    const result = await estimateBridgeGasOrFallback(async () => {
      throw new Error('fail');
    }, 500_000);

    expect(typeof result).toBe('bigint');
    expect(result).toBe(500_000n);
  });

  it('accepts a bigint fallback without coercion', async () => {
    const result = await estimateBridgeGasOrFallback(async () => {
      throw new Error('fail');
    }, 1_250_000n);

    expect(result).toBe(1_250_000n);
  });
});
