const MESSAGE_NOT_RECEIVED_ERRORS = ['B_NOT_RECEIVED', 'B_SIGNAL_NOT_RECEIVED'];

function collectErrorTexts(error: unknown): string[] {
  if (!error || typeof error !== 'object') {
    return [];
  }

  const maybeError = error as {
    message?: unknown;
    shortMessage?: unknown;
    details?: unknown;
    reason?: unknown;
    data?: { errorName?: unknown } | unknown;
    cause?: unknown;
  };

  const currentTexts = [
    maybeError.message,
    maybeError.shortMessage,
    maybeError.details,
    maybeError.reason,
    typeof maybeError.data === 'object' && maybeError.data && 'errorName' in maybeError.data
      ? maybeError.data.errorName
      : undefined,
  ].filter((value): value is string => typeof value === 'string');

  return [...currentTexts, ...collectErrorTexts(maybeError.cause)];
}

export function isMessageNotReceivedError(error: unknown): boolean {
  const haystacks = collectErrorTexts(error);
  return haystacks.some((text) => MESSAGE_NOT_RECEIVED_ERRORS.some((needle) => text.includes(needle)));
}
