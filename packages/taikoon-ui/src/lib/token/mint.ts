import { getAccount, waitForTransactionReceipt, writeContract } from '@wagmi/core';
import { decodeEventLog } from 'viem';

import { chainId } from '$lib/chain';
import { FilterLogsError } from '$lib/error';
import calculateGasPrice from '$lib/util/calculateGasPrice';
import getProof from '$lib/whitelist/getProof';
import { config } from '$wagmi-config';

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi';
import { totalWhitelistMintCount } from '../user/totalWhitelistMintCount';
import { canMint } from './canMint';

export async function mint({
  freeMintCount,
  onTransaction,
}: {
  freeMintCount: number;
  onTransaction: (tx: string) => void;
}): Promise<number[]> {
  const account = getAccount(config);
  if (!account.address) {
    throw new Error('No account address');
  }
  const mintCount = await totalWhitelistMintCount(account.address);

  if (freeMintCount > mintCount) {
    throw new Error('Not enough free mints left');
  }

  let tx: any;

  if (await canMint(account.address)) {
    const proof = getProof(account.address);
    const gasPrice = await calculateGasPrice();
    tx = await writeContract(config, {
      abi: taikoonTokenAbi,
      address: taikoonTokenAddress[chainId],
      functionName: 'mint',
      args: [proof, BigInt(mintCount)],
      chainId,
      gasPrice,
    });

    onTransaction(tx);
  } else {
    throw new Error(`Connected account cannot mint`);
  }

  let tokenId: number = 0;

  const receipt = await waitForTransactionReceipt(config, { hash: tx });

  const tokenIds: number[] = [];

  receipt.logs.forEach((log: any) => {
    try {
      const decoded = decodeEventLog({
        abi: taikoonTokenAbi,
        data: log.data,
        topics: log.topics,
      });

      if (decoded.eventName === 'Transfer') {
        const args: {
          to: string;
          tokenId: bigint;
        } = decoded.args as any;
        tokenId = parseInt(args.tokenId.toString());
        tokenIds.push(tokenId);
      }
    } catch (e: any) {
      throw new FilterLogsError(e.message);
    }
  });
  return tokenIds;
}
