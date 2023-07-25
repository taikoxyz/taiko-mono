import { type Address, getContract, type Hash, type WalletClient } from '@wagmi/core';

import { bridgeABI } from '$abi';
import { chainContractsMap } from '$libs/chain';
import { MessageStatusError, NoOwnerError } from '$libs/error';
import { getLogger } from '$libs/util/logger';

import { MessageStatus } from './types';

const log = getLogger('bridge:beforeClaiming');

type BeforeClaimingArgs = {
  msgHash: Hash;
  ownerAddress: Address;
  wallet: WalletClient;
};

/**
 * We are gonna run some common checks here:
 * 1. Check that the message is owned by the user
 * 2. Check that the message has not already been processed
 * 3. Check that the message has not failed
 * 4. Check that the message is owned by the user
 *
 * If all fine, we get back the message status and the bridge contract
 * in order to continue with the claim
 */
export async function beforeClaiming({ wallet, msgHash, ownerAddress }: BeforeClaimingArgs) {
  const userAddress = wallet.account.address;
  if (ownerAddress.toLowerCase() !== userAddress.toLowerCase()) {
    throw new NoOwnerError('user can not process this as it is not their message');
  }

  const { bridgeAddress } = chainContractsMap[wallet.chain.id];

  const bridgeContract = getContract({
    address: bridgeAddress,
    abi: bridgeABI,

    // Wallet must be connected to the destination chain
    // where the funds will be claimed
    walletClient: wallet,
  });

  const messageStatus: MessageStatus = await bridgeContract.read.getMessageStatus([msgHash]);

  log(`Claiming message with status ${messageStatus}`);

  if (messageStatus === MessageStatus.DONE) {
    throw new MessageStatusError('message already processed');
  }

  if (messageStatus === MessageStatus.FAILED) {
    throw new MessageStatusError('user can not process this as message has failed');
  }

  // We will need these guys to continue with the claim
  return { messageStatus, bridgeContract };
}
