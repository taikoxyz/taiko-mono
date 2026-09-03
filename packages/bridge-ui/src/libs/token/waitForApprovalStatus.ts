import { getLogger } from '$libs/util/logger';

import { ApprovalStatus, getTokenApprovalStatus } from './getTokenApprovalStatus';
import type { NFT, Token } from './types';

const log = getLogger('token:waitForApprovalStatus');

/** How many times the allowance is re-read before the UI accepts the answer */
export const APPROVAL_REFRESH_ATTEMPTS = 5;
/** Gap between re-reads, long enough for a lagging node to catch up */
export const APPROVAL_REFRESH_DELAY_MS = 1500;

type WaitForApprovalStatusDeps = {
  getStatus?: (token: Maybe<Token | NFT>) => Promise<ApprovalStatus>;
  wait?: (ms: number) => Promise<void>;
  /**
   * How many reads to take. The retries exist to outlast a node that has not applied the
   * block yet, so they are only worth taking when an approval may still land. Pass 1 when
   * the approval is known to have failed: the status is not going to change, and the
   * caller holds its spinner up for every attempt.
   */
  attempts?: number;
  /**
   * The status that means "the transaction has not been seen yet", which is the one worth
   * re-reading. It depends on the transition being waited out: an approval moves
   * APPROVAL_REQUIRED -> NO_APPROVAL_REQUIRED, while an allowance reset moves
   * RESET_REQUIRED -> APPROVAL_REQUIRED. Retrying the wrong one both returns the stale
   * answer immediately and burns every attempt on the correct one.
   */
  pendingStatus?: ApprovalStatus;
};

const defaultWait = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

/**
 * @dev Re-reads the approval status until it reflects an approval that has just been mined.
 *
 *      The Approve and Bridge buttons are driven entirely off the allowance this reads. A
 *      single read taken the moment the receipt arrives can still return the pre-approval
 *      allowance, because an RPC gateway may answer from a node that has not applied the
 *      block yet - which leaves Approve enabled and Bridge disabled until the user reloads
 *      the page. Only the caller's pending status is retried: every other status is a
 *      settled answer. A read that throws is retried too, so one RPC blip cannot strand
 *      the buttons.
 *
 * @param token The token whose approval was just submitted
 * @param deps Attempt count, plus an injectable status reader and timer for tests
 * @return status_ The final approval status
 */
export async function waitForApprovalStatus(
  token: Maybe<Token | NFT>,
  deps: WaitForApprovalStatusDeps = {},
): Promise<ApprovalStatus> {
  const getStatus = deps.getStatus ?? getTokenApprovalStatus;
  const wait = deps.wait ?? defaultWait;
  const attempts = Math.max(1, deps.attempts ?? APPROVAL_REFRESH_ATTEMPTS);
  const pendingStatus = deps.pendingStatus ?? ApprovalStatus.APPROVAL_REQUIRED;

  let status: ApprovalStatus | null = null;

  for (let attempt = 0; attempt < attempts; attempt++) {
    if (attempt > 0) await wait(APPROVAL_REFRESH_DELAY_MS);

    try {
      status = await getStatus(token);
    } catch (error) {
      log(`approval status read failed on attempt ${attempt + 1}`, error);
      continue;
    }

    // Anything other than the status we are waiting to move off is a settled answer
    if (status !== pendingStatus) return status;
  }

  if (status === null) throw new Error('Could not read the approval status');
  return status;
}
