import { type Address, formatGwei } from 'viem';

import { chainId } from '$lib/chain';
import getProof from '$lib/whitelist/getProof';

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi';
import { totalWhitelistMintCount } from '../user/totalWhitelistMintCount';
import estimateContractGas from '../wagmi/estimateContractGas';
import { canMint } from './canMint';

export async function estimateMintGasCost(address: Address): Promise<number> {
  const freeMintLeft = await totalWhitelistMintCount(address);

  if (await canMint(address)) {
    const proof = getProof(address);
    const gasEstimate = await estimateContractGas({
      abi: taikoonTokenAbi,
      address: taikoonTokenAddress[chainId],
      functionName: 'mint',
      args: [proof, BigInt(freeMintLeft)],
    });
    // proper parsing for 0-valued gas estimates
    return parseFloat(formatGwei(gasEstimate === 0 ? BigInt(0) : gasEstimate));
  }
  return 0;
}
