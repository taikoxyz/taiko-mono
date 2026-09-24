import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

import type { BridgeTransaction } from '$libs/bridge/types';

const getFinalRetryState = vi.fn();
vi.mock('$libs/bridge/recall', () => ({ getFinalRetryState: (...args: unknown[]) => getFinalRetryState(...args) }));
vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key) };
});

import { selectedRetryMethod } from '../state';
import { RETRY_OPTION } from '../types';
import RetryOptionStep from './RetryOptionStep.svelte';

const bridgeTx = { srcChainId: 1n, destChainId: 2n } as BridgeTransaction;
let target: HTMLElement;
const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

beforeEach(() => {
  target = document.createElement('div');
  document.body.append(target);
  getFinalRetryState.mockReset();
  selectedRetryMethod.set(RETRY_OPTION.CONTINUE);
});
afterEach(() => target.remove());

it.each(['disabled', 'unknown'])('allows only an ordinary retry when recall is %s', async (state) => {
  getFinalRetryState.mockResolvedValue(state);
  selectedRetryMethod.set(RETRY_OPTION.RETRY_ONCE);
  const component = new RetryOptionStep({ target, props: { bridgeTx } });
  await flush();
  expect(target.querySelectorAll('input[type=radio]')).toHaveLength(1);
  expect(get(selectedRetryMethod)).toBe(RETRY_OPTION.CONTINUE);
  expect(target.textContent).toContain(`transactions.retry.recall_${state}`);
  component.$destroy();
});

it('offers both choices when both bridges support recall', async () => {
  getFinalRetryState.mockResolvedValue('enabled');
  const component = new RetryOptionStep({ target, props: { bridgeTx } });
  await flush();
  expect(target.querySelectorAll('input[type=radio]')).toHaveLength(2);
  component.$destroy();
});

it('preserves the final retry selection when polling updates the same transaction', async () => {
  getFinalRetryState.mockResolvedValue('enabled');
  const component = new RetryOptionStep({ target, props: { bridgeTx } });
  await flush();
  selectedRetryMethod.set(RETRY_OPTION.RETRY_ONCE);
  await tick();
  getFinalRetryState.mockClear().mockImplementation(() => new Promise(() => {}));
  component.$set({ bridgeTx: { ...bridgeTx, msgStatus: 1 } });
  await flush();
  expect(get(selectedRetryMethod)).toBe(RETRY_OPTION.RETRY_ONCE);
  expect(target.querySelectorAll('input[type=radio]')).toHaveLength(2);
  expect(getFinalRetryState).not.toHaveBeenCalled();
  component.$destroy();
});

it('ignores an old route response after the transaction changes', async () => {
  let resolveOld!: (state: string) => void;
  getFinalRetryState
    .mockReturnValueOnce(
      new Promise((resolve) => {
        resolveOld = resolve;
      }),
    )
    .mockResolvedValue('disabled');
  const component = new RetryOptionStep({ target, props: { bridgeTx } });
  await tick();
  component.$set({ bridgeTx: { ...bridgeTx, srcChainId: 2n, destChainId: 1n } });
  await flush();
  resolveOld('enabled');
  await flush();
  expect(target.querySelectorAll('input[type=radio]')).toHaveLength(1);
  component.$destroy();
});
