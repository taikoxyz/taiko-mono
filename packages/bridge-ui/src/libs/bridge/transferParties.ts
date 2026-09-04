import { type Address, decodeAbiParameters, decodeFunctionData, getAddress } from 'viem';

import { TokenType } from '$libs/token';
import { getLogger } from '$libs/util/logger';

import type { BridgeTransaction } from './types';
import {
  erc20InvocationParameters,
  erc721InvocationParameters,
  erc1155InvocationParameters,
  onMessageInvocationAbi,
} from './vaultInvocation';

const log = getLogger('bridge:transferParties');

export type TransferParties = {
  sender: Maybe<Address>;
  recipient: Maybe<Address>;
};

// The payload tuples all carry the recipient in the same position: (token, owner, recipient, ...).
// Keyed on the token type the row was recorded or decoded with: the send path sets it from the
// token being bridged, and the relayer service from the vault the message is addressed to
const payloadParameters = {
  [TokenType.ERC20]: erc20InvocationParameters,
  [TokenType.ERC721]: erc721InvocationParameters,
  [TokenType.ERC1155]: erc1155InvocationParameters,
} as const;

/**
 * @dev The addresses a user means by "sender" and "recipient".
 *
 *      An ETH transfer is a message from the sender to the recipient. A token transfer is a
 *      message from the source vault to the destination vault: the owner travels in
 *      `srcOwner`, and the recipient inside the `onMessageInvocation` payload the destination
 *      vault executes. Reading the envelope's `from` and `to` for those showed two bridge
 *      contracts where the user expected their own addresses, and let a self-transfer look
 *      like one to a stranger.
 *
 * @param bridgeTx The transaction, with its message once that has been read
 * @return parties_ The sender and the recipient, each null when it cannot be determined
 */
export function getTransferParties(
  bridgeTx: Pick<BridgeTransaction, 'tokenType' | 'from' | 'message'>,
): TransferParties {
  const { message, tokenType } = bridgeTx;
  const sender = message?.srcOwner ?? bridgeTx.from ?? null;
  if (!message) return { sender, recipient: null };
  if (tokenType === TokenType.ETH) return { sender, recipient: message.to ?? null };

  try {
    const { args } = decodeFunctionData({ abi: onMessageInvocationAbi, data: message.data });
    const [, , recipient] = decodeAbiParameters(payloadParameters[tokenType], args[0]);
    return { sender, recipient: getAddress(recipient) };
  } catch (error) {
    // A vault address is the one answer that must not stand in here
    log('Could not read the recipient from the vault payload', { error, tokenType });
    return { sender, recipient: null };
  }
}
