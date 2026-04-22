import { waitForTransactionReceipt, writeContract } from '@wagmi/core';
import { decodeEventLog } from 'viem';

import { FilterLogsError, MintError } from '$lib/error';
import getProof from '$lib/whitelist/getProof';
import { config } from '$wagmi-config';

import { snaefellTokenAbi, snaefellTokenAddress } from '../../generated/abi';
import { web3modal } from '../../lib/connect';
import type { IChainId } from '../../types';
import { totalWhitelistMintCount } from '../user/totalWhitelistMintCount';
import { canMint } from './canMint';

export async function mint({
  freeMintCount,
  onTransaction,
}: {
  freeMintCount: number;
  onTransaction: (tx: string) => void;
}): Promise<number[]> {
  const { selectedNetworkId } = web3modal.getState();
  if (!selectedNetworkId) return [];
  let tx: any;
  const chainId = selectedNetworkId as IChainId;

  const mintCount = await totalWhitelistMintCount();

  if (freeMintCount > mintCount) {
    throw new MintError('Not enough free mints left');
  }

  if (await canMint()) {
    const proof = getProof();
    tx = await writeContract(config, {
      abi: snaefellTokenAbi,
      address: snaefellTokenAddress[chainId],
      functionName: 'mint',
      args: [proof, BigInt(mintCount)],
      chainId: chainId as number,
    });

    onTransaction(tx);
  }

  let nounId: number = 0;

  const receipt = await waitForTransactionReceipt(config, { hash: tx });

  const tokenIds: number[] = [];

  receipt.logs.forEach((log: any) => {
    try {
      const decoded = decodeEventLog({
        abi: snaefellTokenAbi,
        data: log.data,
        topics: log.topics,
      });

      if (decoded.eventName === 'Transfer') {
        const args: {
          to: string;
          tokenId: bigint;
        } = decoded.args as any;
        nounId = parseInt(args.tokenId.toString());
        tokenIds.push(nounId);
      }
    } catch (e: any) {
      throw new FilterLogsError(e.message);
    }
  });
  return tokenIds;
}
