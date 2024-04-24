export const enum RetrySteps {
  SELECT,
  REVIEW,
  CONFIRM,
}

export const INITIAL_STEP = RetrySteps.SELECT;

export const enum RetryStatus {
  PENDING,
  DONE,
}

export const enum RETRY_OPTION {
  CONTINUE,
  RETRY_ONCE,
}
