import { gasLimitConfig } from '$config';
import { getLogger } from '$libs/util/logger';

const log = getLogger('estimateSendTokenGas');

export async function estimateSendTokenGasOrFallback(estimate: () => Promise<bigint>): Promise<bigint> {
  try {
    const estimatedGas = await estimate();
    log('Gas estimated', estimatedGas);
    return estimatedGas;
  } catch (error) {
    console.error('Failed to estimate gas for sendToken, using fallback', error);
    return BigInt(gasLimitConfig.erc20SendTokenFallbackGasLimit);
  }
}
