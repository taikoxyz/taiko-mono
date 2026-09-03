/**
 * Who claimed a message, and when, read from the claim transaction itself. The relayer API
 * reports neither for a message the relayer claimed, so the details dialog left "Claimed by"
 * and "Claim date" empty for exactly the claims a user most wants to check.
 */
import { getPublicClient } from '@wagmi/core';

import { getClaimDetails } from './getClaimDetails';

vi.mock('@wagmi/core');
vi.mock('$libs/wagmi', () => ({ config: {} }));

const CLAIM_TX = `0x${'cd'.repeat(32)}` as const;
const RELAYER = '0x00006ca990540F6e30e3ef05F085a033Ae67F214';

const getTransaction = vi.fn();
const getBlock = vi.fn();

beforeEach(() => {
  vi.clearAllMocks();
  getTransaction.mockResolvedValue({ from: RELAYER, blockNumber: 5n });
  getBlock.mockResolvedValue({ timestamp: 1_700_000_000n });
  vi.mocked(getPublicClient).mockReturnValue({ getTransaction, getBlock } as never);
});

describe('getClaimDetails', () => {
  it("reads the claimer and the claim time off the claim transaction's chain", async () => {
    expect(await getClaimDetails(CLAIM_TX, 2n)).toEqual({ claimedBy: RELAYER, claimedAt: 1_700_000_000n });

    expect(getPublicClient).toHaveBeenCalledWith(expect.anything(), { chainId: 2 });
    expect(getTransaction).toHaveBeenCalledWith({ hash: CLAIM_TX });
    expect(getBlock).toHaveBeenCalledWith({ blockNumber: 5n });
  });

  it('refuses a transaction that is not mined rather than inventing a claim time', async () => {
    getTransaction.mockResolvedValue({ from: RELAYER, blockNumber: null });

    await expect(getClaimDetails(CLAIM_TX, 2n)).rejects.toThrow(/not mined/);
    expect(getBlock).not.toHaveBeenCalled();
  });

  it('fails loudly without a client for the destination chain', async () => {
    vi.mocked(getPublicClient).mockReturnValue(undefined as never);

    await expect(getClaimDetails(CLAIM_TX, 2n)).rejects.toThrow(/Client not found/);
  });
});
