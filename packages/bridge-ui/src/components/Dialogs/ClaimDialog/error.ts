const MESSAGE_NOT_RECEIVED_ERRORS = ['B_NOT_RECEIVED', 'B_SIGNAL_NOT_RECEIVED'];
const QUOTA_MANAGER_OUT_OF_QUOTA_ERRORS = ['QM_OUT_OF_QUOTA', '0x51d8fe3a'];

function collectErrorTexts(error: unknown): string[] {
  if (!error || typeof error !== 'object') {
    return [];
  }

  const maybeError = error as {
    message?: unknown;
    shortMessage?: unknown;
    details?: unknown;
    reason?: unknown;
    signature?: unknown;
    metaMessages?: unknown;
    data?: { errorName?: unknown } | unknown;
    cause?: unknown;
  };

  const currentTexts = [
    maybeError.message,
    maybeError.shortMessage,
    maybeError.details,
    maybeError.reason,
    maybeError.signature,
    ...(Array.isArray(maybeError.metaMessages) ? maybeError.metaMessages : []),
    typeof maybeError.data === 'string' ? maybeError.data : undefined,
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

export function isQuotaManagerOutOfQuotaError(error: unknown): boolean {
  const haystacks = collectErrorTexts(error);
  return haystacks.some((text) => QUOTA_MANAGER_OUT_OF_QUOTA_ERRORS.some((needle) => text.includes(needle)));
}
