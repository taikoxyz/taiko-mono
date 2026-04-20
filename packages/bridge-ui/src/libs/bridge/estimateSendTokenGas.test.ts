import { gasLimitConfig } from '$config';

import { estimateSendTokenGasOrFallback } from './estimateSendTokenGas';

describe('estimateSendTokenGasOrFallback', () => {
  let errorSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    errorSpy.mockRestore();
  });

  it('returns the estimated gas when estimation succeeds', async () => {
    const estimated = 1_234_567n;
    const result = await estimateSendTokenGasOrFallback(async () => estimated);

    expect(result).toBe(estimated);
    expect(errorSpy).not.toHaveBeenCalled();
  });

  it('returns the configured fallback gas when estimation rejects', async () => {
    const result = await estimateSendTokenGasOrFallback(async () => {
      throw new Error('RPC rejected eth_estimateGas');
    });

    expect(result).toBe(BigInt(gasLimitConfig.erc20SendTokenFallbackGasLimit));
    expect(errorSpy).toHaveBeenCalledWith(
      'Failed to estimate gas for sendToken, using fallback',
      expect.any(Error),
    );
  });

  it('falls back on non-Error rejections', async () => {
    const result = await estimateSendTokenGasOrFallback(async () => {
      // eslint-disable-next-line @typescript-eslint/only-throw-error
      throw 'network down';
    });

    expect(result).toBe(BigInt(gasLimitConfig.erc20SendTokenFallbackGasLimit));
    expect(errorSpy).toHaveBeenCalled();
  });

  it('coerces the numeric config fallback to a bigint', async () => {
    const result = await estimateSendTokenGasOrFallback(async () => {
      throw new Error('fail');
    });

    expect(typeof result).toBe('bigint');
    expect(result).toBe(500_000n);
  });
});
