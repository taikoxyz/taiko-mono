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
  /** The destination owner a successful validation actually completed for, if any */
  validatedDestOwner: Maybe<string>;
  /** The chain the bridge will deliver to */
  destChainId: Maybe<number>;
  invalidRecipient: boolean;
  invalidDestOwner: boolean;
  recipientIsSmartContract: boolean;
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
  if (state.invalidRecipient || state.invalidDestOwner) return false;
  if (!state.recipientDraft) return false;

  // The classification has to belong to the address on screen, on the chain we bridge to
  if (!state.validatedRecipient) return false;
  if (!addressesEqual(state.validatedRecipient.address, state.recipientDraft)) return false;
  if (!state.destChainId || state.validatedRecipient.chainId !== state.destChainId) return false;

  // A contract recipient cannot claim for itself, so it needs a destination owner that
  // passed its own validation - an unvalidated draft would leave $destOwnerAddress null and
  // the bridges fall back to `destOwner = to`, i.e. the very contract that cannot claim.
  if (state.recipientIsSmartContract) {
    if (!state.destOwnerDraft) return false;
    if (!addressesEqual(state.validatedDestOwner, state.destOwnerDraft)) return false;
  }

  return true;
}
