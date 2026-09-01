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
};

const defaultWait = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

/**
 * @dev Re-reads the approval status until it reflects an approval that has just been mined.
 *
 *      The Approve and Bridge buttons are driven entirely off the allowance this reads. A
 *      single read taken the moment the receipt arrives can still return the pre-approval
 *      allowance, because an RPC gateway may answer from a node that has not applied the
 *      block yet - which leaves Approve enabled and Bridge disabled until the user reloads
 *      the page. Only APPROVAL_REQUIRED is retried: every other status is a settled answer.
 *      A read that throws is retried too, so one RPC blip cannot strand the buttons.
 *
 * @param token The token whose approval was just submitted
 * @param deps Injectable status reader and timer, for tests
 * @return status_ The final approval status
 */
export async function waitForApprovalStatus(
  token: Maybe<Token | NFT>,
  deps: WaitForApprovalStatusDeps = {},
): Promise<ApprovalStatus> {
  const getStatus = deps.getStatus ?? getTokenApprovalStatus;
  const wait = deps.wait ?? defaultWait;

  let status: ApprovalStatus | null = null;

  for (let attempt = 0; attempt < APPROVAL_REFRESH_ATTEMPTS; attempt++) {
    if (attempt > 0) await wait(APPROVAL_REFRESH_DELAY_MS);

    try {
      status = await getStatus(token);
    } catch (error) {
      log(`approval status read failed on attempt ${attempt + 1}`, error);
      continue;
    }

    // Anything other than "still needs approving" is a settled answer
    if (status !== ApprovalStatus.APPROVAL_REQUIRED) return status;
  }

  if (status === null) throw new Error('Could not read the approval status');
  return status;
}
