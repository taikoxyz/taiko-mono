import { gasLimitConfig } from '$config';

import { estimateBridgeGasOrFallback, tokenBridgeFallbackGas } from './estimateBridgeGas';

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

describe('tokenBridgeFallbackGas', () => {
  it('returns the supplied baseline when the token is already deployed', () => {
    expect(tokenBridgeFallbackGas(gasLimitConfig.erc20SendTokenFallbackGasLimit, true)).toBe(
      gasLimitConfig.erc20SendTokenFallbackGasLimit,
    );
  });

  it('adds the not-deployed extra gas when the token is not yet deployed', () => {
    expect(tokenBridgeFallbackGas(gasLimitConfig.erc20SendTokenFallbackGasLimit, false)).toBe(
      gasLimitConfig.erc20SendTokenFallbackGasLimit + gasLimitConfig.bridgeTxNotDeployedExtraGas,
    );
  });

  it('treats undefined deployment status as not-deployed', () => {
    expect(tokenBridgeFallbackGas(gasLimitConfig.erc721SendTokenFallbackGasLimit, undefined)).toBe(
      gasLimitConfig.erc721SendTokenFallbackGasLimit + gasLimitConfig.bridgeTxNotDeployedExtraGas,
    );
  });

  it('scales per token type via the supplied baseline', () => {
    const erc20Deployed = tokenBridgeFallbackGas(gasLimitConfig.erc20SendTokenFallbackGasLimit, true);
    const erc1155Deployed = tokenBridgeFallbackGas(gasLimitConfig.erc1155SendTokenFallbackGasLimit, true);
    expect(erc1155Deployed).toBeGreaterThan(erc20Deployed);
  });
});
