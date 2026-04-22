export const enum RetrySteps {
  CHECK,
  SELECT,
  REVIEW,
  CONFIRM,
}

export const INITIAL_STEP = RetrySteps.CHECK;

export const enum RetryStatus {
  PENDING,
  DONE,
}

export const enum RETRY_OPTION {
  CONTINUE,
  RETRY_ONCE,
}
