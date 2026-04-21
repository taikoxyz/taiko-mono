import { getLogger } from '$libs/util/logger';

const log = getLogger('estimateBridgeGas');

export async function estimateBridgeGasOrFallback(
  estimate: () => Promise<bigint>,
  fallbackGas: number | bigint,
): Promise<bigint> {
  try {
    const estimatedGas = await estimate();
    log('Gas estimated', estimatedGas);
    return estimatedGas;
  } catch (error) {
    console.error('Failed to estimate gas for bridge tx, using fallback', error);
    return BigInt(fallbackGas);
  }
}
