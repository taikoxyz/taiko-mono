/**
 * A custom processing fee that never parsed must not be confirmable.
 *
 * `inputProcessFee` deliberately keeps the previous fee for incomplete input (so the value
 * does not jump around mid-keystroke), which means malformed text like `1e5` left
 * `tempprocessingFee` describing something the user had already replaced on screen.
 * Confirm only checked the acknowledgement box, so that stale fee could be submitted.
 */
import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

import { gasLimitZero, processingFee, processingFeeMethod } from '$components/Bridge/state';
import { ProcessingFeeMethod } from '$libs/fee';

import ProcessingFee from './ProcessingFee.svelte';

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

beforeEach(() => {
  gasLimitZero.set(false);
  processingFee.set(BigInt(0));
  processingFeeMethod.set(ProcessingFeeMethod.RECOMMENDED);
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

/** The dialog only explains a bad custom fee through this alert */
const errorShown = () => (target.textContent ?? '').includes('processing_fee.invalid_custom_fee');

const confirmButton = () =>
  Array.from(target.querySelectorAll('button')).find((b) =>
    b.textContent?.includes('common.confirm'),
  ) as HTMLButtonElement;

/**
 * The acknowledgement checkbox is the last one in the dialog. The earlier one toggles
 * gasLimitZero, which switches the method to NONE and removes the fee input entirely.
 */
/** The zero-gas-limit checkbox is the first one in the dialog */
const toggleZeroGasLimit = async () => {
  const checkboxes = Array.from(target.querySelectorAll('input[type="checkbox"]')) as HTMLInputElement[];
  checkboxes[0].click();
  await tick();
};

const cancelButton = () =>
  Array.from(target.querySelectorAll('button')).find((b) =>
    b.textContent?.includes('common.cancel'),
  ) as HTMLButtonElement;

const acknowledge = async () => {
  const checkboxes = Array.from(target.querySelectorAll('input[type="checkbox"]')) as HTMLInputElement[];
  checkboxes[checkboxes.length - 1].click();
  await tick();
};

const flushMicrotasks = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

const type = async (value: string) => {
  const input = feeInput();
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await tick();
};

describe('zero gas limit', () => {
  /**
   * Bridge.sol:200 reverts with B_INVALID_FEE when gasLimit is 0 and fee is not.
   * `unselectNoneIfNotEnoughETH` force-switches the NONE method to RECOMMENDED, which
   * raises the fee above zero - and it did so even while the zero-gas-limit option was
   * on, producing exactly the pairing the contract rejects.
   */
  it('does not switch away from the zero-fee method while the gas limit is zero', async () => {
    gasLimitZero.set(true);
    processingFeeMethod.set(ProcessingFeeMethod.NONE);

    // hasEnoughEth false is what previously forced the method to RECOMMENDED
    component?.$destroy();
    component = new ProcessingFee({ target, props: { hasEnoughEth: false } });
    await tick();

    expect(get(processingFeeMethod)).toBe(ProcessingFeeMethod.NONE);
    expect(get(gasLimitZero) && get(processingFee) !== BigInt(0)).toBe(false);
  });

  it('re-applies the switch when the zero gas limit is turned back off', async () => {
    gasLimitZero.set(true);
    processingFeeMethod.set(ProcessingFeeMethod.NONE);

    component?.$destroy();
    component = new ProcessingFee({ target, props: { hasEnoughEth: false } });
    await tick();
    expect(get(processingFeeMethod)).toBe(ProcessingFeeMethod.NONE);

    // The guard read gasLimitZero with get() inside the called function, which Svelte does
    // not track - so the reason for holding NONE could go away without anything re-running
    gasLimitZero.set(false);
    await tick();

    expect(get(processingFeeMethod)).toBe(ProcessingFeeMethod.RECOMMENDED);
  });

  it('does not commit the zero-gas-limit choice when the dialog is cancelled', async () => {
    // A committed, non-zero fee first - the reactive under test only fired when the
    // committed fee was non-zero, which the recommended fee never is in this harness
    await openCustom();
    await acknowledge();
    await type('0.002');
    confirmButton().click();
    await tick();
    expect(get(processingFeeMethod)).toBe(ProcessingFeeMethod.CUSTOM);
    expect(get(processingFee)).toBe(BigInt('2000000000000000'));

    // Now reopen, look at the zero-gas-limit option, and change your mind
    await openCustom();
    await toggleZeroGasLimit();
    cancelButton()?.click();
    await tick();

    // Toggling the checkbox used to write the committed stores immediately, so Cancel
    // left the method at NONE with fee 0 - the next bridge going out with no relayer fee
    // and silent manual claiming, a state the user had explicitly cancelled
    expect(get(gasLimitZero)).toBe(false);
    expect(get(processingFeeMethod)).toBe(ProcessingFeeMethod.CUSTOM);
    expect(get(processingFee)).toBe(BigInt('2000000000000000'));
  });

  it('clears the zero-gas-limit choice when the fee is reset', async () => {
    gasLimitZero.set(true);
    processingFeeMethod.set(ProcessingFeeMethod.NONE);
    component?.$destroy();
    component = new ProcessingFee({ target, props: { hasEnoughEth: true } });
    await tick();

    (component as unknown as { resetProcessingFee: () => void }).resetProcessingFee();
    await tick();

    // Leaving it set meant the reactive dragged the freshly reset method back to NONE,
    // and the next transfer went out with gasLimit 0 without being acknowledged again
    expect(get(gasLimitZero)).toBe(false);
    expect(get(processingFeeMethod)).toBe(ProcessingFeeMethod.RECOMMENDED);
  });

  it('still switches away from the zero-fee method when the gas limit is not zero', async () => {
    // The guard must be specific to the zero-gas-limit case, not disable the behaviour
    gasLimitZero.set(false);
    processingFeeMethod.set(ProcessingFeeMethod.NONE);

    component?.$destroy();
    component = new ProcessingFee({ target, props: { hasEnoughEth: false } });
    await tick();

    expect(get(processingFeeMethod)).toBe(ProcessingFeeMethod.RECOMMENDED);
  });
});

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

    // Not an error to report...
    expect(errorShown()).toBe(false);
    // ...but there is no fee in it to confirm either
    expect(confirmButton().disabled).toBe(true);
  });

  it('does not submit the previous fee after the box is cleared', async () => {
    await openCustom();
    await acknowledge();
    await type('0.002');
    expect(confirmButton().disabled).toBe(false);

    await type('');

    // tempprocessingFee still holds 0.002, so leaving Confirm enabled here bridged a fee
    // the box no longer shows - the same "what you see is what you bridge" break the
    // amount inputs had
    expect(confirmButton().disabled).toBe(true);
  });

  it('says why a fee that cannot be parsed is blocked', async () => {
    await openCustom();
    await acknowledge();
    await type('1e5');

    expect(confirmButton().disabled).toBe(true);
    expect(errorShown()).toBe(true);
  });

  it('reopens on a committed custom fee without making the user retype it', async () => {
    await openCustom();
    await acknowledge();
    await type('0.002');
    confirmButton().click();
    await tick();
    expect(get(processingFeeMethod)).toBe(ProcessingFeeMethod.CUSTOM);

    await openCustom();
    await flushMicrotasks();

    // The "box must hold a usable fee" rule was never meant to demand a retype just to
    // reach anything else in the dialog
    expect(feeInput().value).toBe('0.002');
    await acknowledge();
    expect(confirmButton().disabled).toBe(false);
  });

  it('reopens on a committed custom fee of zero the same way', async () => {
    // parseCustomFeeInput accepts zero, so a zero fee is a committed custom fee like any
    // other. Gating the prefill on a positive amount left it reopening to an empty box
    // with Confirm disabled until the user retyped a fee they had already chosen
    await openCustom();
    await acknowledge();
    await type('0');
    confirmButton().click();
    await tick();
    expect(get(processingFeeMethod)).toBe(ProcessingFeeMethod.CUSTOM);
    expect(get(processingFee)).toBe(BigInt(0));

    await openCustom();
    await flushMicrotasks();

    expect(feeInput().value).toBe('0');
    await acknowledge();
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
    // draft must not still be reported against it
    expect(feeInput().value).toBe('');
    expect(errorShown()).toBe(false);

    // Confirm is still blocked, but by the empty box rather than by the retired error:
    // typing a valid fee releases it, which it could not do if the error had persisted
    expect(confirmButton().disabled).toBe(true);
    await type('0.002');
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
