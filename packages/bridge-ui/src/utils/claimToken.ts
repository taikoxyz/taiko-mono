import type { BridgeTransaction } from '../domain/transaction';
import { chains } from '../chain/chains';
import type { Chain } from '../domain/chain';
import { switchChainAndSetSigner } from './switchChainAndSetSigner';
import { isOnCorrectChain } from './isOnCorrectChain';
import { ethers, type Signer } from 'ethers';
import { bridges } from '../bridge/bridges';
import { BridgeType } from '../domain/bridge';

// TODO: explain and unit test
export async function claimToken(
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

  // For now just handling this case for when the user has near 0 balance during their first bridge transaction to L2
  // TODO: estimate Claim transaction
  const userBalance = await signer.getBalance('latest');
  if (!userBalance.gt(ethers.utils.parseEther('0.0001'))) {
    throw Error('Insufficient balance');
  }

  const bridgeType =
    bridgeTx.message?.data === '0x' || !bridgeTx.message?.data
      ? BridgeType.ETH
      : BridgeType.ERC20;

  return bridges[bridgeType].claim({
    signer,
    message,
    msgHash,
    destBridgeAddress: chains[toChainId].bridgeAddress,
    srcBridgeAddress: chains[fromChainId].bridgeAddress,
  });
}
