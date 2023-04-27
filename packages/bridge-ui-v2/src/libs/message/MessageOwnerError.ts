/**
 * These errors are thrown when the message owner is wrong
 */
export class MessageOwnerError extends Error {
  constructor(message = 'Wrong message owner') {
    super(message)
    this.name = 'MessageOwnerError'
  }
}
