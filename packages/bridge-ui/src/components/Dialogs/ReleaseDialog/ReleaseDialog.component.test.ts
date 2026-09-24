import { tick } from 'svelte';
import { ContractFunctionRevertedError, encodeErrorResult } from 'viem';
import { vi } from 'vitest';

import { bridgeAbi } from '$abi';
import { MOCK_BRIDGE_TX_1 } from '$mocks';

window.matchMedia = vi
  .fn()
  .mockReturnValue({ matches: true, addEventListener: vi.fn(), removeEventListener: vi.fn() }) as never;
vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});
vi.mock('$chainConfig', async () => {
  const { mainnet, sepolia } = await import('viem/chains');
  return { chainConfig: { 1: mainnet, 2: { ...sepolia, id: 2, name: 'Taiko' } } };
});
vi.mock('$libs/wagmi', () => ({ config: {} }));
vi.mock('$components/NotificationToast/NotificationToast.svelte', () => ({
  errorToast: vi.fn(),
  warningToast: vi.fn(),
  infoToast: vi.fn(),
  successToast: vi.fn(),
}));
vi.mock('$components/Dialogs/Claim.svelte', async () => ({
  default: (await import('../../../tests/ClaimStub.svelte')).default,
}));
vi.mock('../Shared', async () => ({
  ClaimConfirmStep: (await import('../Shared/ClaimConfirmStep.svelte')).default,
  ReviewStep: (await import('../../../tests/StubComponent.svelte')).default,
}));
const getRecallState = vi.fn();
vi.mock('$libs/bridge/recall', () => ({ getRecallState: (...args: unknown[]) => getRecallState(...args) }));

import { warningToast } from '$components/NotificationToast/NotificationToast.svelte';
import { account } from '$stores/account';
import { connectedSourceChain } from '$stores/network';

import { claimControl, type ScriptedOutcome } from '../../../tests/ClaimStub.svelte';
import ReleaseDialog from './ReleaseDialog.svelte';

const bridgeTx = { ...MOCK_BRIDGE_TX_1, srcChainId: 1n, destChainId: 2n, msgStatus: 3 };
let target: HTMLElement;
let component: ReleaseDialog;
const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};
const button = (key: string) => [...target.querySelectorAll('button')].find((el) => el.textContent?.trim() === key);
const mount = async () => {
  component = new ReleaseDialog({ target, props: { bridgeTx, dialogOpen: true } });
  await flush();
};
const atConfirm = async () => {
  await mount();
  button('common.continue')!.click();
  await flush();
  button('common.confirm')!.click();
  await flush();
};
const releaseButton = () => target.querySelector('#actions button') as HTMLButtonElement | null;

beforeEach(() => {
  vi.clearAllMocks();
  getRecallState.mockReset().mockResolvedValue('enabled');
  claimControl.next = undefined;
  account.set({ address: '0x1111111111111111111111111111111111111111', isConnected: true } as never);
  connectedSourceChain.set({ id: 1 } as never);
  target = document.createElement('div');
  document.body.append(target);
});
afterEach(() => {
  component?.$destroy();
  target.remove();
});

it.each(['disabled', 'unknown'])('blocks even a directly opened release dialog when recall is %s', async (state) => {
  getRecallState.mockResolvedValue(state);
  await mount();
  expect(button('common.continue')).toBeUndefined();
  expect(target.textContent).toContain(`bridge.errors.recall.${state}.message`);
});

it('rechecks availability on reopening after an upgrade', async () => {
  await mount();
  expect(button('common.continue')).toBeDefined();
  component.$set({ dialogOpen: false });
  await flush();
  getRecallState.mockResolvedValue('disabled');
  component.$set({ dialogOpen: true });
  await flush();
  expect(button('common.continue')).toBeUndefined();
});

it('preserves the confirm step when polling updates the same transaction', async () => {
  await atConfirm();
  getRecallState.mockClear().mockImplementation(() => new Promise(() => {}));
  component.$set({ bridgeTx: { ...bridgeTx, blockNumber: '0x2' } });
  await flush();
  expect(releaseButton()?.disabled).toBe(false);
  expect(getRecallState).not.toHaveBeenCalled();
});

it('shows a decoded recall-disabled error to the user', async () => {
  await atConfirm();
  expect(releaseButton()?.disabled).toBe(false);
  claimControl.next = Promise.resolve({
    error: new ContractFunctionRevertedError({
      abi: bridgeAbi,
      functionName: 'recallMessage',
      data: encodeErrorResult({ abi: bridgeAbi, errorName: 'B_RECALL_DISABLED' }),
    }),
  });
  releaseButton()!.click();
  await flush();
  expect(warningToast).toHaveBeenCalledWith({
    title: 'bridge.errors.recall.disabled.title',
    message: 'bridge.errors.recall.disabled.message',
  });
});

it('keeps a pending wallet request in flight when recall is disabled on reopening', async () => {
  await atConfirm();
  let settle!: (outcome: ScriptedOutcome) => void;
  claimControl.next = new Promise((resolve) => {
    settle = resolve;
  });
  releaseButton()!.click();
  await flush();
  document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
  await flush();
  getRecallState.mockResolvedValue('disabled');
  component.$set({ dialogOpen: true });
  await flush();
  expect(releaseButton()?.disabled).toBe(true);
  settle({ error: new Error('cancelled') });
  await flush();
  expect(releaseButton()).toBeNull();
  expect(target.textContent).toContain('bridge.errors.recall.disabled.message');
});
