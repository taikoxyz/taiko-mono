/**
 * These errors are thrown when the message status is not as expected
 */
export class MessageStatusError extends Error {
  constructor(message = 'Wrong message status') {
    super(message)
    this.name = 'MessageStatusError'
  }
}
