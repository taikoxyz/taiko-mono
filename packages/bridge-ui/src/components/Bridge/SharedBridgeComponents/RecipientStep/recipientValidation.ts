import type { Address } from 'viem';

/**
 * @dev The recipient dialog's safety invariant, extracted so it can be unit tested.
 *      A smart-contract recipient cannot claim on the destination chain itself, so it
 *      always needs an alternate destination owner. Classifying the recipient requires
 *      an RPC round trip, and until it completes we do not know whether that owner is
 *      required — so confirming must be blocked rather than assume the previous answer.
 */
export type RecipientDialogState = {
  recipientAddress: Maybe<Address>;
  destOwnerAddress: Maybe<Address>;
  invalidRecipient: boolean;
  invalidDestOwner: boolean;
  /** Whether the recipient was successfully determined to be a contract */
  recipientIsSmartContract: boolean;
  /** A classification RPC for the current recipient is still in flight */
  validatingRecipient: boolean;
  /** The current recipient has been successfully classified (RPC neither pending nor failed) */
  recipientClassified: boolean;
};

/**
 * @dev Decides whether the recipient dialog may be confirmed.
 * @param state The dialog's current state
 * @return Whether confirming is allowed
 */
export function canConfirmRecipient(state: RecipientDialogState): boolean {
  // A pending classification means "contract or not" is still unknown
  if (state.validatingRecipient) return false;

  if (state.invalidRecipient || state.invalidDestOwner) return false;

  if (!state.recipientAddress) return false;

  // A failed or never-run classification cannot prove the recipient is claimable
  if (!state.recipientClassified) return false;

  if (state.recipientIsSmartContract && !state.destOwnerAddress) return false;

  return true;
}
