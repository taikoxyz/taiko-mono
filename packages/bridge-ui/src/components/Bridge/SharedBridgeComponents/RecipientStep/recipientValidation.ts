/**
 * The exact pair a smart-contract classification was performed on. A classification only
 * speaks for the address it ran against, on the destination chain it ran against: the same
 * address is a contract on one chain and an EOA on another.
 */
export type ValidatedRecipient = {
  address: string;
  chainId: number;
};

export type RecipientDialogState = {
  /** Raw value the recipient input currently holds */
  recipientDraft: Maybe<string>;
  /** Raw value the destination owner input currently holds */
  destOwnerDraft: Maybe<string>;
  /** The recipient a classification actually completed for, if any */
  validatedRecipient: Maybe<ValidatedRecipient>;
  /** The destination owner a successful validation completed for, and the chain it ran on */
  validatedDestOwner: Maybe<ValidatedRecipient>;
  /** The chain the bridge will deliver to */
  destChainId: Maybe<number>;
  invalidRecipient: boolean;
  invalidDestOwner: boolean;
  recipientIsSmartContract: boolean;
  /** Whether the destination owner entered is itself a contract */
  destOwnerIsSmartContract: boolean;
  validatingRecipient: boolean;
};

/** Addresses are compared case-insensitively: the same address can be checksummed or not. */
export const addressesEqual = (a: Maybe<string>, b: Maybe<string>): boolean =>
  !!a && !!b && a.toLowerCase() === b.toLowerCase();

/**
 * Whether the recipient dialog may be confirmed.
 *
 * The dialog cannot trust validation events alone: AddressInput stays silent for a cleared
 * field and for text without a `0x` prefix, so a draft can change without any handler
 * running. Confirming therefore requires a validation whose subject still equals what the
 * input holds right now, rather than a flag that some earlier validation set.
 */
export function canConfirmRecipient(state: RecipientDialogState): boolean {
  if (state.validatingRecipient) return false;
  if (state.invalidRecipient) return false;
  if (!state.recipientDraft) return false;

  // The classification has to belong to the address on screen, on the chain we bridge to
  if (!state.validatedRecipient) return false;
  if (!addressesEqual(state.validatedRecipient.address, state.recipientDraft)) return false;
  if (!state.destChainId || state.validatedRecipient.chainId !== state.destChainId) return false;

  // A contract recipient cannot claim for itself, so it needs a destination owner that
  // passed its own validation - an unvalidated draft would leave $destOwnerAddress null and
  // the bridges fall back to `destOwner = to`, i.e. the very contract that cannot claim.
  if (state.recipientIsSmartContract) {
    // Only relevant while an owner is actually being asked for: once the recipient is a
    // plain wallet the field is gone, and a flag left behind by a discarded draft would
    // block Confirm with no visible control that could clear it
    if (state.invalidDestOwner) return false;
    // A contract destination owner cannot be relied on to call processMessage either, so it
    // leaves a gasLimit-0 message with nobody able to process it. The standalone DestOwner
    // dialog refuses one; this field writes the same store and must agree.
    if (state.destOwnerIsSmartContract) return false;
    if (!state.destOwnerDraft) return false;
    if (!addressesEqual(state.validatedDestOwner?.address, state.destOwnerDraft)) return false;
    // The owner's classification is chain-specific too, so an answer from the previous
    // destination chain is no answer here
    if (state.validatedDestOwner?.chainId !== state.destChainId) return false;
  }

  return true;
}

export type DestOwnerDialogState = {
  /** Raw value the destination owner input currently holds */
  draft: Maybe<string>;
  /** The address a classification actually completed for, if any */
  validated: Maybe<ValidatedRecipient>;
  /** The chain the bridge will deliver to */
  destChainId: Maybe<number>;
  invalidAddress: boolean;
  isSmartContract: boolean;
  validating: boolean;
};

/**
 * Whether the destination-owner dialog may be confirmed.
 *
 * Same rule as `canConfirmRecipient` and for the same reason: AddressInput stays silent for
 * a cleared field and for text without a `0x` prefix, so `invalidAddress` alone can describe
 * an address the box no longer holds. Replacing a validated address with `bob.eth` used to
 * leave Confirm enabled while the store still held the previous value.
 *
 * The destination owner is the one address that can process a `gasLimit: 0` message or drive
 * a last-attempt retry, so committing an unvalidated one is value-bearing.
 */
export function canConfirmDestOwner(state: DestOwnerDialogState): boolean {
  if (state.validating) return false;
  if (state.invalidAddress) return false;
  if (state.isSmartContract) return false;
  if (!state.draft) return false;
  if (!state.validated) return false;
  if (!addressesEqual(state.validated.address, state.draft)) return false;
  // A classification only speaks for the chain it ran against: the same address is a
  // contract on one chain and an EOA on another
  return !!state.destChainId && state.validated.chainId === state.destChainId;
}
