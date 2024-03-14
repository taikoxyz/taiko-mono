export const enum ClaimSteps {
  CHECK,
  REVIEW,
  CONFIRM,
}

export const INITIAL_STEP = ClaimSteps.CHECK;

export const enum ClaimTypes {
  CLAIM,
  RETRY,
  RELEASE,
}
