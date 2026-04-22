export const enum ClaimSteps {
  CHECK,
  REVIEW,
  CONFIRM,
}

export const INITIAL_STEP = ClaimSteps.CHECK;

export const enum ClaimStatus {
  PENDING,
  DONE,
}

export const enum TWO_STEP_STATE {
  PROVE,
  CLAIM,
}
