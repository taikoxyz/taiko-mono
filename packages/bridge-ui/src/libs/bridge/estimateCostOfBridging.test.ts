/**
 * The cost estimate reserves what the wallet actually locks up. Under-reserving is the
 * failure this function exists to prevent, so every path that could yield a zero or
 * missing fee per gas has to fall back rather than multiply by it.
 */
const estimateFeesPerGas = vi.fn();
const getGasPrice = vi.fn();
const getPublicClient = vi.fn();
vi.mock('@wagmi/core', () => ({
  getPublicClient: (...args: unknown[]) => getPublicClient(...args),
}));
vi.mock('$libs/wagmi', () => ({ config: {} }));

import { estimateCostOfBridging } from './estimateCostOfBridging';

const bridge = { estimateGas: vi.fn() } as never;
const args = { srcChainId: 167000 } as never;

beforeEach(() => {
  vi.clearAllMocks();
  getPublicClient.mockReturnValue({
    estimateFeesPerGas: (...args: unknown[]) => estimateFeesPerGas(...args),
    getGasPrice: (...args: unknown[]) => getGasPrice(...args),
  });
  (bridge as unknown as { estimateGas: ReturnType<typeof vi.fn> }).estimateGas.mockResolvedValue(BigInt(21_000));
  getGasPrice.mockResolvedValue(BigInt(7));
});

describe('estimateCostOfBridging', () => {
  it('reserves against the EIP-1559 max fee when there is one', async () => {
    estimateFeesPerGas.mockResolvedValue({ maxFeePerGas: BigInt(10) });

    expect(await estimateCostOfBridging(bridge, args)).toBe(BigInt(210_000));
    expect(getGasPrice).not.toHaveBeenCalled();
  });

  it('falls back to the legacy gas price when the estimate is absent', async () => {
    estimateFeesPerGas.mockResolvedValue({ maxFeePerGas: null });

    expect(await estimateCostOfBridging(bridge, args)).toBe(BigInt(147_000));
  });

  it('falls back when the estimate rejects outright', async () => {
    estimateFeesPerGas.mockRejectedValue(new Error('no EIP-1559 on this chain'));

    expect(await estimateCostOfBridging(bridge, args)).toBe(BigInt(147_000));
  });

  it('treats a zero max fee as unavailable rather than as free', async () => {
    // `??` only falls back on null or undefined, so a chain answering 0n produced a cost
    // estimate of zero - the under-reservation this whole function exists to prevent
    estimateFeesPerGas.mockResolvedValue({ maxFeePerGas: BigInt(0) });

    expect(await estimateCostOfBridging(bridge, args)).toBe(BigInt(147_000));
  });

  it('reads the fee market of the source chain, not of whatever chain the wallet is on', async () => {
    // Without a chainId the client resolves against the connected chain. The two differ
    // during a network switch, and L1 and Taiko gas prices are orders of magnitude apart:
    // a MAX derived from the wrong one is either unsendable or leaves the wallet short of gas
    estimateFeesPerGas.mockResolvedValue({ maxFeePerGas: BigInt(10) });

    await estimateCostOfBridging(bridge, args);

    expect(getPublicClient).toHaveBeenCalledWith(expect.anything(), { chainId: 167000 });
  });
});
