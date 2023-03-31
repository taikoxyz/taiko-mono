import type { Signer } from 'ethers';
import { BridgeType } from '../domain/bridge';
import { chains } from '../chain/chains';
import type { Chain } from '../domain/chain';
import type { BridgeTransaction } from '../domain/transaction';
import { isOnCorrectChain } from './isOnCorrectChain';
import { switchChainAndSetSigner } from './switchChainAndSetSigner';
import { providers } from '../provider/providers';
import { tokenVaults } from '../vault/tokenVaults';
import { bridges } from '../bridge/bridges';

export async function releaseTokens(
  bridgeTx: BridgeTransaction,
  currentChain: Chain,
  signer: Signer,
) {
  const { fromChainId, toChainId, message, msgHash } = bridgeTx;

  if (currentChain.id !== fromChainId) {
    const chain = chains[fromChainId];
    await switchChainAndSetSigner(chain);
  }

  // confirm after switch chain that it worked.
  const correctChain = await isOnCorrectChain(signer, toChainId);
  if (!correctChain) {
    throw Error('You are connected to the wrong chain in your wallet');
  }

  const bridgeType =
    message?.data === '0x' || !message?.data
      ? BridgeType.ETH
      : BridgeType.ERC20;

  return bridges[bridgeType].releaseTokens({
    signer,
    message,
    msgHash,
    destBridgeAddress: chains[toChainId].bridgeAddress,
    srcBridgeAddress: chains[fromChainId].bridgeAddress,
    destProvider: providers[toChainId],
    srcTokenVaultAddress: tokenVaults[fromChainId],
  });
}
