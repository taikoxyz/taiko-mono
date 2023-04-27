export class InvalidProofError extends Error {
  constructor(message = 'Invalid proof') {
    super(message)
    this.name = 'InvalidProofError'
  }
}
