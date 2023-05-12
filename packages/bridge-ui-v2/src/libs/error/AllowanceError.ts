export enum AllowanceErrorCause {
  REQUIRES_ALLOWANCE = 'REQUIRES_ALLOWANCE',
  ALREADY_HAS_ALLOWANCE = 'ALREADY_HAS_ALLOWANCE',
}

/**
 * There is some issue with the allowance.
 */
export class AllowanceError extends Error {
  name = 'AllowanceError'
}
