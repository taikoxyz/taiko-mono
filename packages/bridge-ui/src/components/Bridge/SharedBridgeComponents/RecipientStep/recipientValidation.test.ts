import { canConfirmRecipient, type RecipientDialogState } from './recipientValidation';

const WALLET = '0x1111111111111111111111111111111111111111';
const CONTRACT = '0x2222222222222222222222222222222222222222';
const DEST_OWNER = '0x3333333333333333333333333333333333333333';
const DEST_CHAIN = 167000;
const OTHER_CHAIN = 1;

/** A plain wallet recipient that has been classified on the current destination chain */
const validState = (overrides: Partial<RecipientDialogState> = {}): RecipientDialogState => ({
  recipientDraft: WALLET,
  destOwnerDraft: null,
  validatedRecipient: { address: WALLET, chainId: DEST_CHAIN },
  validatedDestOwner: null,
  destChainId: DEST_CHAIN,
  invalidRecipient: false,
  invalidDestOwner: false,
  recipientIsSmartContract: false,
  destOwnerIsSmartContract: false,
  validatingRecipient: false,
  ...overrides,
});

/** A smart-contract recipient with a fully validated destination owner */
const contractState = (overrides: Partial<RecipientDialogState> = {}): RecipientDialogState =>
  validState({
    recipientDraft: CONTRACT,
    validatedRecipient: { address: CONTRACT, chainId: DEST_CHAIN },
    recipientIsSmartContract: true,
    destOwnerDraft: DEST_OWNER,
    validatedDestOwner: { address: DEST_OWNER, chainId: DEST_CHAIN },
    ...overrides,
  });

describe('canConfirmRecipient', () => {
  it('allows a classified wallet recipient', () => {
    expect(canConfirmRecipient(validState())).toBe(true);
  });

  it('allows a contract recipient once a destination owner is validated', () => {
    expect(canConfirmRecipient(contractState())).toBe(true);
  });

  it('blocks while a classification is in flight', () => {
    expect(canConfirmRecipient(validState({ validatingRecipient: true }))).toBe(false);
  });

  it('blocks an invalid recipient or destination owner', () => {
    expect(canConfirmRecipient(validState({ invalidRecipient: true }))).toBe(false);
    expect(canConfirmRecipient(contractState({ invalidDestOwner: true }))).toBe(false);
  });

  it('blocks an empty recipient', () => {
    expect(canConfirmRecipient(validState({ recipientDraft: null }))).toBe(false);
    expect(canConfirmRecipient(validState({ recipientDraft: '' }))).toBe(false);
  });

  it('blocks a recipient that was never classified', () => {
    expect(canConfirmRecipient(validState({ validatedRecipient: null }))).toBe(false);
  });

  it('compares the classification against the address case-insensitively', () => {
    const state = validState({ recipientDraft: WALLET.toUpperCase().replace('0X', '0x') });
    expect(canConfirmRecipient(state)).toBe(true);
  });

  describe('a classification only speaks for what it ran on', () => {
    it('blocks when the draft moved on from the classified address', () => {
      // AddressInput dispatches nothing for text without a `0x` prefix, so the flags still
      // describe the previous address while the input already holds something else
      expect(canConfirmRecipient(validState({ recipientDraft: 'abc' }))).toBe(false);
      expect(canConfirmRecipient(validState({ recipientDraft: CONTRACT }))).toBe(false);
    });

    it('blocks when the destination chain changed after classification', () => {
      // The same address is a contract on one chain and an EOA on another
      expect(canConfirmRecipient(validState({ destChainId: 1 }))).toBe(false);
    });

    it('blocks when there is no destination chain at all', () => {
      expect(canConfirmRecipient(validState({ destChainId: null }))).toBe(false);
    });
  });

  describe('destination owner required for a contract recipient', () => {
    it('blocks when the destination owner is missing', () => {
      expect(canConfirmRecipient(contractState({ destOwnerDraft: null, validatedDestOwner: null }))).toBe(false);
    });

    it('blocks an unvalidated destination owner draft', () => {
      // Reproduces the reported hole: typing `abc` makes the draft truthy, but
      // AddressInput never dispatches for it so validateDestOwner never ran and
      // $destOwnerAddress is still null - the bridges would fall back to
      // `destOwner = to`, the contract that cannot claim
      expect(canConfirmRecipient(contractState({ destOwnerDraft: 'abc', validatedDestOwner: null }))).toBe(false);
    });

    it('blocks when the draft no longer matches the validated destination owner', () => {
      expect(canConfirmRecipient(contractState({ destOwnerDraft: WALLET }))).toBe(false);
    });

    it('matches the validated destination owner case-insensitively', () => {
      const state = contractState({ destOwnerDraft: DEST_OWNER.toUpperCase().replace('0X', '0x') });
      expect(canConfirmRecipient(state)).toBe(true);
    });

    it('ignores a destination owner when the recipient is a plain wallet', () => {
      expect(canConfirmRecipient(validState({ destOwnerDraft: 'abc', validatedDestOwner: null }))).toBe(true);
    });

    it('ignores a destination-owner error left behind by a discarded contract recipient', () => {
      // Classify contract C, enter an invalid owner, then replace C with a plain wallet.
      // The owner field is gone, so nothing on screen could clear its error flag.
      expect(canConfirmRecipient(validState({ invalidDestOwner: true }))).toBe(true);
    });
  });

  it('refuses a destination owner that is itself a contract', () => {
    // It cannot be relied on to call processMessage either, so a gasLimit-0 message would
    // have nobody able to process it. The standalone DestOwner dialog refuses one and this
    // field writes the same store.
    expect(canConfirmRecipient(contractState({ destOwnerIsSmartContract: true }))).toBe(false);
  });

  it('refuses an owner classified on the previous destination chain', () => {
    // The same address is a contract on one chain and an EOA on another, so an answer
    // carried across a switch - or restored from the store on a remount - is no answer here
    expect(
      canConfirmRecipient(contractState({ validatedDestOwner: { address: DEST_OWNER, chainId: OTHER_CHAIN } })),
    ).toBe(false);
  });
});
