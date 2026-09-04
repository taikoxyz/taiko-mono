/**
 * The send path builds a precise diagnosis - the bridge is paused, the message would be
 * rejected - and this is the last step before the user sees it. Both used to fall through to
 * "unknown error", which discarded exactly the information that tells them what to do next.
 */
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

const errorToast = vi.fn();
const warningToast = vi.fn();
vi.mock('$components/NotificationToast', () => ({
  errorToast: (...args: unknown[]) => errorToast(...args),
  warningToast: (...args: unknown[]) => warningToast(...args),
  successToast: vi.fn(),
  infoToast: vi.fn(),
}));

import { BridgePausedError, InvalidMessageError, TransactionTimeoutError } from '$libs/error';

import { handleBridgeError } from './handleBridgeErrors';

beforeEach(() => {
  errorToast.mockReset();
  warningToast.mockReset();
});

describe('handleBridgeError', () => {
  it('tells the user the bridge is paused rather than that something unknown went wrong', () => {
    handleBridgeError(new BridgePausedError('Bridge is paused'));

    expect(warningToast).toHaveBeenCalledWith({
      title: 'bridge.errors.bridge_paused.title',
      message: 'bridge.errors.bridge_paused.message',
    });
    expect(errorToast).not.toHaveBeenCalled();
  });

  it('names a message the contract would reject', () => {
    handleBridgeError(new InvalidMessageError('Message violates: ZERO_RECIPIENT'));

    expect(errorToast).toHaveBeenCalledWith({
      title: 'bridge.errors.invalid_message.title',
      message: 'bridge.errors.invalid_message.message',
    });
  });

  it('still classifies a timeout as a warning', () => {
    handleBridgeError(new TransactionTimeoutError('timed out'));

    expect(warningToast).toHaveBeenCalledWith({
      title: 'bridge.errors.transaction_timeout.title',
      message: 'bridge.errors.transaction_timeout.message',
    });
  });

  it('falls back to the unknown error for anything else', () => {
    handleBridgeError(new Error('boom'));

    expect(errorToast).toHaveBeenCalledWith({
      title: 'bridge.errors.unknown_error.title',
      message: 'bridge.errors.unknown_error.message',
    });
  });
});
