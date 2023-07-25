import { getContract, type Address, type Hash, type WalletClient } from '@wagmi/core';

import { bridgeABI } from '$abi';
import { MessageStatusError, NoOwnerError } from '$libs/error';
import { getLogger } from '$libs/util/logger';

import { MessageStatus } from './types';
import { chainContractsMap } from '$libs/chain';

const log = getLogger('bridge:beforeClaiming');

type BeforeClaimingArgs = {
  msgHash: Hash;
  ownerAddress: Address;
  wallet: WalletClient;
}

export async function beforeClaiming({ wallet, msgHash, ownerAddress }: BeforeClaimingArgs) {
  // We are gonna run some common checks here:
  // 1. Check that the message is owned by the user
  // 2. Check that the message has not already been processed
  // 3. Check that the message has not failed
  // 4. Check that the message is owned by the user

  const userAddress = wallet.account.address;
  if (ownerAddress.toLowerCase() !== userAddress.toLowerCase()) {
    throw new NoOwnerError('user can not process this as it is not their message');
  }

  const { bridgeAddress } = chainContractsMap[wallet.chain.id]

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

  return {messageStatus, bridgeContract};
}
