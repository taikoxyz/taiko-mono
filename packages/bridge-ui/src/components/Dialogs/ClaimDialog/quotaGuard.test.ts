import type { BridgeTransaction } from '$libs/bridge/types';

import { claimWithQuotaGuard } from './quota';

vi.mock('$libs/bridge/checkQuota', () => ({
  isClaimBlockedByQuota: vi.fn().mockResolvedValue(false),
}));

const bridgeTx = { srcTxHash: '0xabc' } as unknown as BridgeTransaction;

describe('claimWithQuotaGuard', () => {
  it('clears the claiming flag when claim() throws instead of reporting via its events', async () => {
    // Claim.svelte can reject (e.g. NotConnectedError) without dispatching an event;
    // the dialog would otherwise stay stuck in the claiming spinner forever
    const setClaiming = vi.fn();
    const claim = vi.fn().mockRejectedValue(new Error('not connected'));

    await expect(
      claimWithQuotaGuard({
        bridgeTx,
        claim,
        setClaiming,
        showQuotaReachedToast: vi.fn(),
      }),
    ).rejects.toThrow('not connected');

    expect(setClaiming).toHaveBeenNthCalledWith(1, true);
    expect(setClaiming).toHaveBeenLastCalledWith(false);
  });

  it('leaves the claiming flag to the event path on success', async () => {
    const setClaiming = vi.fn();
    const claim = vi.fn().mockResolvedValue(undefined);

    await claimWithQuotaGuard({ bridgeTx, claim, setClaiming, showQuotaReachedToast: vi.fn() });

    expect(setClaiming).toHaveBeenCalledTimes(1);
    expect(setClaiming).toHaveBeenCalledWith(true);
  });
});
