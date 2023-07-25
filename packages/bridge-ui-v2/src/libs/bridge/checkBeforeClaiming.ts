import { getContract } from '@wagmi/core';

import { bridgeABI } from '$abi';
import { MessageStatusError, NoOwnerError } from '$libs/error';
import { getLogger } from '$libs/util/logger';

import { type ClaimArgs, MessageStatus } from './types';

const log = getLogger('bridge:checkBeforeClaiming');

export async function checkBeforeClaiming({ msgHash, destBridgeAddress, destChainId, wallet, message }: ClaimArgs) {
  // We are gonna run some common checks here:
  // 1. Check that the message is owned by the user
  // 2. Check that the message has not already been processed
  // 3. Check that the message has not failed
  // 4. Check that the message is owned by the user

  const userAddress = wallet.account.address;
  if (message.owner.toLowerCase() !== userAddress.toLowerCase()) {
    throw new NoOwnerError('user can not process this as it is not their message');
  }

  const destBridgeContract = getContract({
    address: destBridgeAddress,
    abi: bridgeABI,
    chainId: destChainId,
  });

  const messageStatus: MessageStatus = await destBridgeContract.read.getMessageStatus([msgHash]);

  log(`Claiming message with status ${messageStatus}`);

  if (messageStatus === MessageStatus.DONE) {
    throw new MessageStatusError('message already processed');
  }

  if (messageStatus === MessageStatus.FAILED) {
    throw new MessageStatusError('user can not process this as message has failed');
  }

  return messageStatus;
}
