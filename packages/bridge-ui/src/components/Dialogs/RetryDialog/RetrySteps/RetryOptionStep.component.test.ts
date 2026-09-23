import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key) };
});

const isTransactionRecallEnabled = vi.fn();
vi.mock('$libs/bridge', () => ({
  isTransactionRecallEnabled: (...args: unknown[]) => isTransactionRecallEnabled(...args),
}));

import { selectedRetryMethod } from '../state';
import { RETRY_OPTION } from '../types';
import RetryOptionStep from './RetryOptionStep.svelte';

const bridgeTx = { msgHash: '0x1' } as never;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

let target: HTMLElement;

beforeEach(() => {
  vi.clearAllMocks();
  selectedRetryMethod.set(RETRY_OPTION.CONTINUE);
  target = document.createElement('div');
  document.body.appendChild(target);
});

afterEach(() => target.remove());

it('hides the final-attempt option when recalls are disabled', async () => {
  isTransactionRecallEnabled.mockResolvedValue(false);

  new RetryOptionStep({ target, props: { bridgeTx } });
  await flush();

  expect(target.textContent).toContain('transactions.retry.options.recall_disabled_description');
  expect(target.textContent).not.toContain('transactions.retry.options.final');
});

it('offers the final-attempt option when recalls are enabled', async () => {
  isTransactionRecallEnabled.mockResolvedValue(true);

  new RetryOptionStep({ target, props: { bridgeTx } });
  await flush();

  expect(target.textContent).toContain('transactions.retry.options.final');
});

it('resets a stale final-attempt selection while recalls are disabled', async () => {
  selectedRetryMethod.set(RETRY_OPTION.RETRY_ONCE);
  isTransactionRecallEnabled.mockResolvedValue(false);

  new RetryOptionStep({ target, props: { bridgeTx } });
  await flush();

  expect(get(selectedRetryMethod)).toBe(RETRY_OPTION.CONTINUE);
});
