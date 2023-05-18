import { Contract, ethers } from 'ethers';
import { tokenVaults } from '../vault/tokenVaults';
import type { BridgeTransaction } from '../domain/transactions';
import { isETHByMessage } from './isETHByMessage';
import { chains } from '../chain/chains';
import { providers } from '../provider/providers';
import { bridgeABI, tokenVaultABI } from '../constants/abi';

// This only makes sense when the status if FAILED
export async function isEthOrTokenReleased(
  bridgeTx: BridgeTransaction,
): Promise<boolean> {
  const { fromChainId, msgHash } = bridgeTx;

  const srcChain = chains[fromChainId];
  const srcProvider = providers[fromChainId];

  if (isETHByMessage(bridgeTx.message)) {
    const srcBridgeContract = new Contract(
      srcChain.bridgeAddress,
      bridgeABI,
      srcProvider,
    );

    return srcBridgeContract.isEtherReleased(msgHash);
  }

  // We're dealing with ERC20 tokens

  const srcTokenVaultContract = new Contract(
    tokenVaults[fromChainId],
    tokenVaultABI,
    srcProvider,
  );

  const { token, amount } = await srcTokenVaultContract.messageDeposits(
    msgHash,
  );

  // If the transaction has failed, and this condition is met,
  // then it means we have actaully released the tokens
  // We don't have something like isERC20Released
  return token === ethers.constants.AddressZero && amount.eq(0);
}
