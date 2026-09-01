/**
 * The conditions the bridge contracts enforce on a message, restated so the UI cannot build
 * one that is guaranteed to revert. Each rule below cites the contract that owns it; when a
 * contract changes, this file is the place that has to follow.
 *
 * Bridge.sendMessage (shared/bridge/Bridge.sol)
 *   - srcOwner, destOwner and `to` are all non-zero          nonZeroAddr
 *   - destChainId is non-zero and differs from the source    B_INVALID_CHAINID
 *   - gasLimit == 0 implies fee == 0                         B_INVALID_FEE
 *   - gasLimit != 0 implies gasLimit > minGasLimit(data)     B_INVALID_GAS_LIMIT
 *
 * ERC20Vault.sendToken (shared/vault/ERC20Vault.sol)
 *   - amount != 0                                            VAULT_INVALID_AMOUNT
 *   - token != address(0)                                    VAULT_INVALID_TOKEN
 *
 * ERC721Vault / ERC1155Vault (shared/vault/*.sol)
 *   - tokenIds and amounts are the same length               VAULT_TOKEN_ARRAY_MISMATCH
 *   - every ERC721 amount is 0                               VAULT_INVALID_AMOUNT
 *   - every ERC1155 amount is non-zero                       VAULT_INVALID_AMOUNT
 */

import { InvalidMessageError } from '$libs/error';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

export type MessageInvariantViolation =
  | 'ZERO_RECIPIENT'
  | 'ZERO_DEST_OWNER'
  | 'SAME_CHAIN'
  | 'MISSING_DEST_CHAIN'
  | 'FEE_WITH_ZERO_GAS_LIMIT'
  | 'GAS_LIMIT_BELOW_MINIMUM'
  | 'ZERO_AMOUNT'
  | 'ZERO_TOKEN_ADDRESS'
  | 'TOKEN_ARRAY_MISMATCH'
  | 'NON_ZERO_ERC721_AMOUNT'
  | 'ZERO_ERC1155_AMOUNT';

const isZeroAddress = (address: Maybe<string>) => !address || address.toLowerCase() === ZERO_ADDRESS;

export type CommonMessageFields = {
  to: Maybe<string>;
  destOwner: Maybe<string>;
  srcChainId: Maybe<number>;
  destChainId: Maybe<number>;
  gasLimit: number;
  fee: bigint;
  /** Omit when the minimum is not known; the rule is then skipped rather than guessed */
  minGasLimit?: number;
};

/** @dev Rules Bridge.sendMessage applies to every message, whatever the token */
export function checkCommonMessage(message: CommonMessageFields): MessageInvariantViolation[] {
  const violations: MessageInvariantViolation[] = [];

  if (isZeroAddress(message.to)) violations.push('ZERO_RECIPIENT');
  if (isZeroAddress(message.destOwner)) violations.push('ZERO_DEST_OWNER');
  if (!message.destChainId) violations.push('MISSING_DEST_CHAIN');
  else if (message.destChainId === message.srcChainId) violations.push('SAME_CHAIN');

  if (message.gasLimit === 0) {
    // Only the destination owner can process a zero-gas-limit message, so a fee has no
    // recipient and the bridge refuses to take one
    if (message.fee !== BigInt(0)) violations.push('FEE_WITH_ZERO_GAS_LIMIT');
  } else if (message.minGasLimit !== undefined && message.gasLimit <= message.minGasLimit) {
    // The contract subtracts the minimum and rejects a remainder of zero, so the limit has
    // to exceed the minimum outright rather than merely reach it
    violations.push('GAS_LIMIT_BELOW_MINIMUM');
  }

  return violations;
}

/** @dev Adds the ERC20Vault rules to the common ones */
export function checkERC20Message(
  message: CommonMessageFields & { amount: bigint; tokenAddress: Maybe<string> },
): MessageInvariantViolation[] {
  const violations = checkCommonMessage(message);
  if (message.amount === BigInt(0)) violations.push('ZERO_AMOUNT');
  if (isZeroAddress(message.tokenAddress)) violations.push('ZERO_TOKEN_ADDRESS');
  return violations;
}

/** @dev Adds the ERC721Vault rules: amounts travel alongside the ids but must all be zero */
export function checkERC721Message(
  message: CommonMessageFields & { tokenAddress: Maybe<string>; tokenIds: bigint[]; amounts: bigint[] },
): MessageInvariantViolation[] {
  const violations = checkCommonMessage(message);
  if (isZeroAddress(message.tokenAddress)) violations.push('ZERO_TOKEN_ADDRESS');
  if (message.tokenIds.length !== message.amounts.length) violations.push('TOKEN_ARRAY_MISMATCH');
  if (message.amounts.some((amount) => amount !== BigInt(0))) violations.push('NON_ZERO_ERC721_AMOUNT');
  return violations;
}

/** @dev Adds the ERC1155Vault rules: every amount carries a quantity and must be non-zero */
export function checkERC1155Message(
  message: CommonMessageFields & { tokenAddress: Maybe<string>; tokenIds: bigint[]; amounts: bigint[] },
): MessageInvariantViolation[] {
  const violations = checkCommonMessage(message);
  if (isZeroAddress(message.tokenAddress)) violations.push('ZERO_TOKEN_ADDRESS');
  if (message.tokenIds.length !== message.amounts.length) violations.push('TOKEN_ARRAY_MISMATCH');
  if (message.amounts.some((amount) => amount === BigInt(0))) violations.push('ZERO_ERC1155_AMOUNT');
  return violations;
}

/** @dev ETH goes straight to Bridge.sendMessage, so only the common rules apply */
export const checkETHMessage = checkCommonMessage;

/**
 * @dev Throws when a message breaks any of the rules above.
 *
 *      Called from the bridges just before the contract call, so a message that cannot
 *      succeed is refused here with the rule it breaks rather than on chain as a bare
 *      selector. `0xc9f51787` reaching a user as "reverted with the following signature"
 *      is what this exists to prevent.
 *
 * @param violations The result of one of the check functions above
 * @param context What was being sent, for the error message
 */
export function assertNoViolations(violations: MessageInvariantViolation[], context: string): void {
  if (violations.length === 0) return;
  throw new InvalidMessageError(`${context} would be rejected by the bridge: ${violations.join(', ')}`);
}
