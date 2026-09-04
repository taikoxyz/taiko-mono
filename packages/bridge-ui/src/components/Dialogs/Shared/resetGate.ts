/**
 * Gates a dialog's reset on its action being idle.
 *
 * A dialog rewinds to its first step when it closes or the account changes. While its action
 * is in flight - the wallet prompt is open, a proof is being built, or the transaction is on
 * chain with its outcome unknown - that rewind would also clear the in-flight flag, and the
 * dialog reopened from the transaction row would offer the same claim a second time. So a
 * reset requested in flight is refused and remembered, and applied by `settle` once the
 * action has finished - but only while the dialog is closed: a user looking at the confirm
 * step after a rejected signature expects to retry from there, not from the pre-check.
 */
export type ResetGate = {
  /** Rewinds now, or remembers to once the action settles. Returns whether it rewound. */
  request: () => boolean;
  /** Applies a refused rewind, provided the action has settled and the dialog is closed. */
  settle: () => void;
};

export function createResetGate({
  inFlight,
  isOpen,
  rewind,
}: {
  inFlight: () => boolean;
  isOpen: () => boolean;
  rewind: () => void;
}): ResetGate {
  let deferred = false;

  return {
    request: () => {
      if (inFlight()) {
        deferred = true;
        return false;
      }
      deferred = false;
      rewind();
      return true;
    },
    settle: () => {
      if (!deferred || inFlight() || isOpen()) return;
      deferred = false;
      rewind();
    },
  };
}
