import type { Address } from 'viem';

import { canConfirmRecipient, type RecipientDialogState } from './recipientValidation';

const WALLET = '0x1111111111111111111111111111111111111111' as Address;
const CONTRACT = '0x2222222222222222222222222222222222222222' as Address;
const DEST_OWNER = '0x3333333333333333333333333333333333333333' as Address;

// A plain wallet recipient that finished classification: the confirmable baseline
const confirmable: RecipientDialogState = {
  recipientAddress: WALLET,
  destOwnerAddress: null,
  invalidRecipient: false,
  invalidDestOwner: false,
  recipientIsSmartContract: false,
  validatingRecipient: false,
  recipientClassified: true,
};

describe('canConfirmRecipient', () => {
  it('allows confirming a classified wallet recipient', () => {
    expect(canConfirmRecipient(confirmable)).toBe(true);
  });

  it('blocks confirming while the smart-contract lookup is still in flight', () => {
    // The regression: during the RPC window recipientIsSmartContract still holds the
    // previous answer, so a contract could be confirmed without a destination owner
    expect(
      canConfirmRecipient({
        ...confirmable,
        recipientAddress: CONTRACT,
        validatingRecipient: true,
        recipientClassified: false,
      }),
    ).toBe(false);
  });

  it('blocks confirming when classification never ran or failed', () => {
    expect(canConfirmRecipient({ ...confirmable, recipientClassified: false })).toBe(false);
  });

  it('blocks a smart-contract recipient without a destination owner', () => {
    expect(canConfirmRecipient({ ...confirmable, recipientAddress: CONTRACT, recipientIsSmartContract: true })).toBe(
      false,
    );
  });

  it('allows a smart-contract recipient once a destination owner is set', () => {
    expect(
      canConfirmRecipient({
        ...confirmable,
        recipientAddress: CONTRACT,
        recipientIsSmartContract: true,
        destOwnerAddress: DEST_OWNER,
      }),
    ).toBe(true);
  });

  it('blocks on invalid recipient or destination owner input', () => {
    expect(canConfirmRecipient({ ...confirmable, invalidRecipient: true })).toBe(false);
    expect(canConfirmRecipient({ ...confirmable, invalidDestOwner: true })).toBe(false);
  });

  it('blocks when no recipient address is set', () => {
    expect(canConfirmRecipient({ ...confirmable, recipientAddress: null })).toBe(false);
  });
});
