export enum MessageStatusErrorCause {
  MESSAGE_ALREADY_PROCESSED = 'MESSAGE_ALREADY_PROCESSED',
  MESSAGE_ALREADY_FAILED = 'MESSAGE_ALREADY_FAILED',
  UNEXPECTED_MESSAGE_STATUS = 'UNEXPECTED_MESSAGE_STATUS',
}

/**
 * These errors are thrown when the message status is not as expected.
 */
export class MessageStatusError extends Error {
  name = 'MessageStatusError'
}
