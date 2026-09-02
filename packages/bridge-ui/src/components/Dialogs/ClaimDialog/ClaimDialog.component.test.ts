/**
 * Closing the claim dialog does not cancel a claim that is already in the wallet or on chain.
 *
 * Escape, the X button and the backdrop all reset the dialog. Reset used to rewind the steps
 * and clear `claiming` whenever no transaction hash had arrived yet - which is the whole
 * window in which the wallet prompt is open - so reopening the dialog from the row offered
 * a fresh, enabled Claim button for the same message, and a user who signed both paid for a
 * second transaction that reverts.
 */
import { tick } from 'svelte';
import { UserRejectedRequestError } from 'viem';
import { vi } from 'vitest';

window.matchMedia = vi.fn().mockReturnValue({
  matches: true,
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
}) as never;

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});
vi.mock('$chainConfig', () => ({ chainConfig: {} }));
vi.mock('$components/NotificationToast/NotificationToast.svelte', () => ({
  errorToast: vi.fn(),
  warningToast: vi.fn(),
  infoToast: vi.fn(),
  successToast: vi.fn(),
}));
// The wallet round trip is scripted by the test
vi.mock('$components/Dialogs/Claim.svelte', async () => ({
  default: (await import('../../../tests/ClaimStub.svelte')).default,
}));
vi.mock('../Shared/ClaimPreCheck.svelte', async () => ({
  default: (await import('../../../tests/PreCheckStub.svelte')).default,
}));
vi.mock('../Shared', async () => ({
  ClaimConfirmStep: (await import('../Shared/ClaimConfirmStep.svelte')).default,
  ReviewStep: (await import('../../../tests/StubComponent.svelte')).default,
}));
// The quota check reads the chain; what matters here is the guard's contract of raising the
// claiming flag and running the claim
vi.mock('./quota', () => ({
  claimWithQuotaGuard: async ({
    claim,
    setClaiming,
  }: {
    claim: () => Promise<void>;
    setClaiming: (v: boolean) => void;
  }) => {
    setClaiming(true);
    await claim();
  },
  showQuotaToastForClaimError: vi.fn().mockResolvedValue(false),
}));
const reportDialogTransaction = vi.fn();
vi.mock('../Shared/dialogTransactionFlow', () => ({
  reportDialogTransaction: (...args: unknown[]) => reportDialogTransaction(...args),
}));

import { errorToast, warningToast } from '$components/NotificationToast/NotificationToast.svelte';
import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { BlockNotSyncedError, ProofGenerationError, WrongBridgeConfigError } from '$libs/error';
import { TokenType } from '$libs/token';
import { account } from '$stores/account';

import { claimControl, type ScriptedOutcome } from '../../../tests/ClaimStub.svelte';
import ClaimDialog from './ClaimDialog.svelte';
import { ClaimSteps } from './types';

const ADDRESS = '0x1111111111111111111111111111111111111111';

const bridgeTx = {
  srcTxHash: '0xaaaa',
  msgHash: '0xcccc',
  status: MessageStatus.NEW,
  msgStatus: MessageStatus.NEW,
  from: ADDRESS,
  amount: 1n,
  symbol: 'ETH',
  decimals: 18,
  srcChainId: 1n,
  destChainId: 2n,
  tokenType: TokenType.ETH,
  message: {
    srcChainId: 1n,
    destChainId: 2n,
    from: ADDRESS,
    to: ADDRESS,
    srcOwner: ADDRESS,
    destOwner: ADDRESS,
    value: 1n,
    data: '0x',
    fee: 0n,
    gasLimit: 1,
    id: 1n,
  },
} as unknown as BridgeTransaction;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

let target: HTMLElement;
let component: ClaimDialog | null = null;

/** The Claim button of the confirm step, absent on any other step */
const claimButton = () => target.querySelector('#actions button') as HTMLButtonElement | null;
const preCheck = () => target.querySelector('[data-testid="pre-check"]');
const pressEscape = () => document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
const reopen = async () => {
  component!.$set({ dialogOpen: true });
  // The close-on-escape action re-attaches its listeners a macrotask after the update lands
  await tick();
  await flush();
};

/** Mounts open on the pre-check, which passes at once, then moves to the confirm step */
const mountAtConfirm = async () => {
  component = new ClaimDialog({ target, props: { bridgeTx, dialogOpen: true } });
  await flush();
  component.$set({ activeStep: ClaimSteps.CONFIRM });
  await flush();
  expect(claimButton()?.disabled).toBe(false);
};

const scriptWalletPrompt = () => {
  let resolveOutcome!: (outcome: ScriptedOutcome) => void;
  claimControl.next = new Promise<ScriptedOutcome>((resolve) => (resolveOutcome = resolve));
  return resolveOutcome;
};

const rejectedByWallet = () => ({ error: new UserRejectedRequestError(new Error('rejected')) });

beforeEach(() => {
  vi.clearAllMocks();
  account.set({ address: ADDRESS, isConnected: true } as never);
  claimControl.next = undefined;
  target = document.createElement('div');
  document.body.appendChild(target);
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('closing the claim dialog while a claim is in flight', () => {
  it('keeps the claim off the table while the wallet prompt is open', async () => {
    await mountAtConfirm();
    const walletAnswers = scriptWalletPrompt();
    claimButton()!.click();
    await flush();
    expect(claimButton()?.disabled).toBe(true);

    pressEscape();
    await flush();
    await reopen();

    // Still on the confirm step, and Claim still disabled: the first request is in the wallet
    expect(preCheck()).toBeNull();
    expect(claimButton()?.disabled).toBe(true);

    walletAnswers(rejectedByWallet());
    await flush();

    // The user is looking at the dialog, so they retry from here rather than from the start
    expect(claimButton()?.disabled).toBe(false);
  });

  it('rewinds a dialog closed during the wallet prompt once the wallet rejects', async () => {
    await mountAtConfirm();
    const walletAnswers = scriptWalletPrompt();
    claimButton()!.click();
    await flush();
    pressEscape();
    await flush();

    walletAnswers(rejectedByWallet());
    await flush();
    await reopen();

    expect(preCheck()).not.toBeNull();
  });

  it('rewinds a dialog closed while its transaction was pending once that transaction fails', async () => {
    await mountAtConfirm();
    claimControl.next = Promise.resolve({ txHash: '0xdead' });
    let settle!: (outcome: 'failed') => void;
    reportDialogTransaction.mockReturnValue(new Promise((resolve) => (settle = resolve)));
    claimButton()!.click();
    await flush();

    pressEscape();
    await flush();
    await reopen();
    // On chain with the outcome unknown: nothing to offer
    expect(claimButton()?.disabled).toBe(true);
    pressEscape();
    await flush();

    settle('failed');
    await flush();
    await reopen();

    // The reverted claim is over; the next attempt starts from the pre-check, not from a
    // confirm step whose button was never re-checked
    expect(preCheck()).not.toBeNull();
  });

  it('rewinds at once when nothing is in flight', async () => {
    await mountAtConfirm();

    pressEscape();
    await flush();
    await reopen();

    expect(preCheck()).not.toBeNull();
  });
});

/**
 * A claim can be refused before any transaction exists: BridgeProver throws when the destination
 * chain has not synced the source block yet, or cannot build a proof against the state it has.
 * That is the same "not yet" a B_SIGNAL_NOT_RECEIVED revert reports, but it used to fall through
 * to "Unknown error - please try again", which reads as a failure rather than as a wait.
 */
describe('a claim the prover refuses before any transaction', () => {
  const notSyncedToast = {
    title: 'bridge.errors.claim.not_synced.title',
    message: 'bridge.errors.claim.not_synced.message',
  };

  const claimRefusedWith = async (error: unknown) => {
    await mountAtConfirm();
    claimControl.next = Promise.resolve({ error });
    claimButton()!.click();
    await flush();
  };

  beforeEach(() => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  it('reports a source block the destination chain has not synced as not synced yet', async () => {
    await claimRefusedWith(new BlockNotSyncedError('block is not synced yet'));

    expect(warningToast).toHaveBeenCalledWith(notSyncedToast);
    expect(errorToast).not.toHaveBeenCalled();
    // Nothing was sent, so the same button serves the retry once the block has synced
    expect(claimButton()?.disabled).toBe(false);
  });

  it('reports a proof that cannot be built against the synced state the same way', async () => {
    await claimRefusedWith(new ProofGenerationError('proof will not be valid, expected storageProof to not be 0'));

    expect(warningToast).toHaveBeenCalledWith(notSyncedToast);
    expect(errorToast).not.toHaveBeenCalled();
    expect(claimButton()?.disabled).toBe(false);
  });

  it('reports a misconfiguration the prover detected as an unknown error, not as a wait', async () => {
    // The one refusal the prover knows to be permanent: the anchor keeps its checkpoints in a
    // contract other than the configured SignalService. Telling the user to wait would be a lie
    await claimRefusedWith(new WrongBridgeConfigError("Anchor's checkpointStore does NOT match SignalService"));

    expect(errorToast).toHaveBeenCalledWith({
      title: 'bridge.errors.unknown_error.title',
      message: 'bridge.errors.unknown_error.message',
    });
    expect(warningToast).not.toHaveBeenCalled();
  });

  it('still reports a failure it cannot classify as an unknown error', async () => {
    await claimRefusedWith(new Error('boom'));

    expect(errorToast).toHaveBeenCalledWith({
      title: 'bridge.errors.unknown_error.title',
      message: 'bridge.errors.unknown_error.message',
    });
    expect(warningToast).not.toHaveBeenCalled();
  });
});
