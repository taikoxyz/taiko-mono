import { Contract, ethers } from 'ethers';

import { chains } from '../chain/chains';
import { bridgeABI, tokenVaultABI } from '../constants/abi';
import { MessageStatus } from '../domain/message';
import {
  type BridgeTransaction,
  TxExtendedStatus,
} from '../domain/transaction';
import { providers } from '../provider/providers';
import { tokenVaults } from '../vault/tokenVaults';
import { isETHByMessage } from './isETHByMessage';

export async function isEthOrTokenReleased(
  bridgeTx: BridgeTransaction,
): Promise<boolean> {
  const { srcChainId, msgHash, status } = bridgeTx;

  if (status === TxExtendedStatus.Released) return true;

  // This only makes sense if the transaction has failed
  if (status !== MessageStatus.Failed) return false;

  // At this point the transaction has failed, so we need to check

  const srcChain = chains[srcChainId];
  const srcProvider = providers[srcChainId];

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
    tokenVaults[srcChainId],
    tokenVaultABI,
    srcProvider,
  );

  const { token, amount } = await srcTokenVaultContract.messageDeposits(
    msgHash,
  );

  // If the transaction has failed, and this condition is met,
  // then it means we have actually released the tokens
  // We don't have something like isERC20Released
  return token === ethers.constants.AddressZero && amount.eq(0);
}
