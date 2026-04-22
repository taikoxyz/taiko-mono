import { formatGwei } from 'viem';

import getProof from '$lib/whitelist/getProof';

import { snaefellTokenAbi, snaefellTokenAddress } from '../../generated/abi';
import type { IChainId } from '../../types';
import { web3modal } from '../connect';
import { totalWhitelistMintCount } from '../user/totalWhitelistMintCount';
import estimateContractGas from '../wagmi/estimateContractGas';
import { canMint } from './canMint';

export async function estimateMintGasCost(): Promise<number> {
  const { selectedNetworkId } = web3modal.getState();
  if (!selectedNetworkId) return 0;
  const chainId = selectedNetworkId as IChainId;

  const freeMintLeft = await totalWhitelistMintCount();

  if (await canMint()) {
    const proof = getProof();

    const gasEstimate = await estimateContractGas({
      abi: snaefellTokenAbi,
      address: snaefellTokenAddress[chainId],
      functionName: 'mint',
      args: [proof, BigInt(freeMintLeft)],
    });
    return parseFloat(formatGwei(gasEstimate));
  }
  return 0;
}
