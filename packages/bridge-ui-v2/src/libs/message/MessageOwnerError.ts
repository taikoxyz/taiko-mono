// TODO: if it's the only cause, should this not
//       be already set when instantiating the error?
export enum MessageOwnerErrorCause {
  NO_MESSAGE_OWNER = 'NO_MESSAGE_OWNER',
}

/**
 * This error is thrown when there is a problem
 * with the message's owner.
 */
export class MessageOwnerError extends Error {
  name = 'MessageOwnerError'
}
