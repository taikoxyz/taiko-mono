import { vi } from 'vitest';

import { ApprovalStatus } from './getTokenApprovalStatus';
import { APPROVAL_REFRESH_ATTEMPTS, waitForApprovalStatus } from './waitForApprovalStatus';

/**
 * After an approval transaction is mined the Approve button must disable and Bridge must
 * enable on their own. Both are driven off this status, and a single read taken the moment
 * the receipt arrives can still return the pre-approval allowance from a lagging node -
 * which is what forced a page reload before Bridge would light up.
 */
const token = { symbol: 'TKN' } as never;
const wait = vi.fn().mockResolvedValue(undefined);

beforeEach(() => wait.mockClear());

describe('waitForApprovalStatus', () => {
  it('returns a settled answer without waiting', async () => {
    const getStatus = vi.fn().mockResolvedValue(ApprovalStatus.NO_APPROVAL_REQUIRED);

    const status = await waitForApprovalStatus(token, { getStatus, wait });

    expect(status).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);
    expect(getStatus).toHaveBeenCalledTimes(1);
    expect(wait).not.toHaveBeenCalled();
  });

  it('re-reads until a lagging node reflects the approval', async () => {
    // The allowance the node serves is still the pre-approval one for two reads
    const getStatus = vi
      .fn()
      .mockResolvedValueOnce(ApprovalStatus.APPROVAL_REQUIRED)
      .mockResolvedValueOnce(ApprovalStatus.APPROVAL_REQUIRED)
      .mockResolvedValue(ApprovalStatus.NO_APPROVAL_REQUIRED);

    const status = await waitForApprovalStatus(token, { getStatus, wait });

    expect(status).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);
    expect(getStatus).toHaveBeenCalledTimes(3);
    expect(wait).toHaveBeenCalledTimes(2);
  });

  it('retries through a failing read rather than stranding the buttons', async () => {
    const getStatus = vi
      .fn()
      .mockRejectedValueOnce(new Error('rpc down'))
      .mockResolvedValue(ApprovalStatus.NO_APPROVAL_REQUIRED);

    const status = await waitForApprovalStatus(token, { getStatus, wait });

    expect(status).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);
    expect(getStatus).toHaveBeenCalledTimes(2);
  });

  it('gives up after a bounded number of attempts', async () => {
    const getStatus = vi.fn().mockResolvedValue(ApprovalStatus.APPROVAL_REQUIRED);

    const status = await waitForApprovalStatus(token, { getStatus, wait });

    // A genuine "not approved" must still be reported, not retried forever
    expect(status).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    expect(getStatus).toHaveBeenCalledTimes(APPROVAL_REFRESH_ATTEMPTS);
  });

  it('does not retry a reset-required answer', async () => {
    // USDT-style: a settled answer that happens not to be "approved"
    const getStatus = vi.fn().mockResolvedValue(ApprovalStatus.RESET_REQUIRED);

    const status = await waitForApprovalStatus(token, { getStatus, wait });

    expect(status).toBe(ApprovalStatus.RESET_REQUIRED);
    expect(getStatus).toHaveBeenCalledTimes(1);
  });

  it('throws only when every read failed', async () => {
    const getStatus = vi.fn().mockRejectedValue(new Error('rpc down'));

    await expect(waitForApprovalStatus(token, { getStatus, wait })).rejects.toThrow('Could not read the approval');
    expect(getStatus).toHaveBeenCalledTimes(APPROVAL_REFRESH_ATTEMPTS);
  });

  describe('attempt count', () => {
    it('takes a single read when told the approval already failed', async () => {
      const getStatus = vi.fn().mockResolvedValue(ApprovalStatus.APPROVAL_REQUIRED);
      const wait = vi.fn().mockResolvedValue(undefined);

      const status = await waitForApprovalStatus(token, { getStatus, wait, attempts: 1 });

      // A reverted approval is not going to become approved, and the caller keeps its
      // spinner up for every attempt spent finding that out
      expect(getStatus).toHaveBeenCalledTimes(1);
      expect(wait).not.toHaveBeenCalled();
      expect(status).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    });

    it('still polls the full count by default', async () => {
      const getStatus = vi.fn().mockResolvedValue(ApprovalStatus.APPROVAL_REQUIRED);
      const wait = vi.fn().mockResolvedValue(undefined);

      await waitForApprovalStatus(token, { getStatus, wait });

      expect(getStatus).toHaveBeenCalledTimes(APPROVAL_REFRESH_ATTEMPTS);
    });

    it('never takes fewer than one read', async () => {
      const getStatus = vi.fn().mockResolvedValue(ApprovalStatus.NO_APPROVAL_REQUIRED);

      await waitForApprovalStatus(token, { getStatus, wait: vi.fn(), attempts: 0 });

      expect(getStatus).toHaveBeenCalledTimes(1);
    });
  });
});
