import type { Signer } from 'ethers';
import { BridgeType } from '../domain/bridge';
import { chains } from '../chain/chains';
import type { ChainID } from '../domain/chain';
import type { BridgeTransaction } from '../domain/transaction';
import { providers } from '../provider/providers';
import { tokenVaults } from '../vault/tokenVaults';
import { bridges } from '../bridge/bridges';
import { chainCheck } from './chainCheck';

// TODO: explain and unit test
export async function releaseToken(
  bridgeTx: BridgeTransaction,
  currentChainId: ChainID,
  signer: Signer,
) {
  const { fromChainId, toChainId, message, msgHash } = bridgeTx;

  chainCheck(currentChainId, toChainId, signer);

  const bridgeType =
    message?.data === '0x' || !message?.data
      ? BridgeType.ETH
      : BridgeType.ERC20;

  return bridges[bridgeType].releaseToken({
    signer,
    message,
    msgHash,
    destBridgeAddress: chains[toChainId].bridgeAddress,
    srcBridgeAddress: chains[fromChainId].bridgeAddress,
    destProvider: providers[toChainId],
    srcTokenVaultAddress: tokenVaults[fromChainId],
  });
}
