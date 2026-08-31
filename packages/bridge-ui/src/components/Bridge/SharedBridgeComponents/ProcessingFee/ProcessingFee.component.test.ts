/**
 * A custom processing fee that never parsed must not be confirmable.
 *
 * `inputProcessFee` deliberately keeps the previous fee for incomplete input (so the value
 * does not jump around mid-keystroke), which means malformed text like `1e5` left
 * `tempprocessingFee` describing something the user had already replaced on screen.
 * Confirm only checked the acknowledgement box, so that stale fee could be submitted.
 */
import { tick } from 'svelte';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

import ProcessingFee from './ProcessingFee.svelte';

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

beforeEach(() => {
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new ProcessingFee({ target, props: {} });
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

/** Opens the dialog and switches it to the CUSTOM fee method */
const openCustom = async () => {
  const edit = Array.from(target.querySelectorAll('button')).find((b) =>
    b.textContent?.includes('common.edit'),
  ) as HTMLButtonElement;
  edit.click();
  await tick();

  (target.querySelector('#input-custom') as HTMLInputElement).click();
  await tick();
};

const feeInput = () => target.querySelector('input[type="number"]') as HTMLInputElement;

const confirmButton = () =>
  Array.from(target.querySelectorAll('button')).find((b) =>
    b.textContent?.includes('common.confirm'),
  ) as HTMLButtonElement;

/**
 * The acknowledgement checkbox is the last one in the dialog. The earlier one toggles
 * gasLimitZero, which switches the method to NONE and removes the fee input entirely.
 */
const acknowledge = async () => {
  const checkboxes = Array.from(target.querySelectorAll('input[type="checkbox"]')) as HTMLInputElement[];
  checkboxes[checkboxes.length - 1].click();
  await tick();
};

const type = async (value: string) => {
  const input = feeInput();
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await tick();
};

describe('custom processing fee', () => {
  it('switches to the custom method', async () => {
    await openCustom();
    expect(feeInput()).toBeTruthy();
  });

  it('allows confirming a well-formed custom fee', async () => {
    await openCustom();
    await type('0.001');
    await acknowledge();

    expect(confirmButton().disabled).toBe(false);
  });

  it('blocks confirming exponent notation that never parsed', async () => {
    await openCustom();
    await type('0.001');
    await acknowledge();
    expect(confirmButton().disabled).toBe(false);

    // A number input emits this natively; parseCustomFeeInput rejects it, so the fee
    // still held is 0.001 - an amount no longer on screen
    await type('1e5');

    expect(confirmButton().disabled).toBe(true);
  });

  it('re-enables confirm once the input parses again', async () => {
    await openCustom();
    await acknowledge();
    await type('1e5');
    expect(confirmButton().disabled).toBe(true);

    await type('0.002');
    expect(confirmButton().disabled).toBe(false);
  });

  it('treats an empty box as not-yet-filled rather than invalid', async () => {
    await openCustom();
    await acknowledge();
    await type('');

    expect(confirmButton().disabled).toBe(false);
  });

  it('clears the invalid draft across a CUSTOM -> RECOMMENDED -> CUSTOM round trip', async () => {
    await openCustom();
    await acknowledge();
    await type('1e5');
    expect(confirmButton().disabled).toBe(true);

    (target.querySelector('#input-recommended') as HTMLInputElement).click();
    await tick();
    (target.querySelector('#input-custom') as HTMLInputElement).click();
    await tick();

    // The round trip recreates an empty input, so the error belonging to the discarded
    // draft must not still be blocking it
    // The acknowledgement from before the round trip is still checked
    expect(feeInput().value).toBe('');
    expect(confirmButton().disabled).toBe(false);
  });

  it('clears the invalid draft when leaving the custom method', async () => {
    await openCustom();
    await acknowledge();
    await type('1e5');
    expect(confirmButton().disabled).toBe(true);

    (target.querySelector('#input-recommended') as HTMLInputElement).click();
    await tick();

    // Back on RECOMMENDED nothing needs confirming, and the invalid draft is retired
    expect(confirmButton().disabled).toBe(false);
  });
});
