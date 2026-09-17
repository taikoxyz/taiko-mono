/**
 * The typed data is what the contracts verify: an EIP-2612 permit over the token's own domain
 * naming the vault as spender, and a Permit2 transfer of exactly the amount to the vault.
 */
import { type Address, type Hex, maxUint256, type WalletClient } from 'viem';
import { vi } from 'vitest';

import { ALICE } from '$mocks';

const readContract = vi.fn();
vi.mock('@wagmi/core', () => ({ readContract: (...args: unknown[]) => readContract(...args) }));
vi.mock('$libs/wagmi', () => ({ config: {} }));

import { PERMIT_SIGNATURE_TTL_SECONDS } from './constants';
import { PERMIT_TYPES, PERMIT2_TYPES, permitDeadline, signPermit, signPermit2Transfer } from './signatures';

const VAULT = '0x1000010000000000000000000000000000000002' as Address;
const PERMIT2 = '0x000000000022D473030F116dDEE9F6B43aC78BA3' as Address;
const TOKEN = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599' as Address;
const DOMAIN = { name: 'Token', version: '1', chainId: 1, verifyingContract: TOKEN };
const R = `0x${'11'.repeat(32)}` as Hex;
const S = `0x${'22'.repeat(32)}` as Hex;

const signTypedData = vi.fn();
const wallet = { account: { address: ALICE }, signTypedData } as unknown as WalletClient;

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers({ now: 1_700_000_000_000 });
  readContract.mockResolvedValue(7n);
  signTypedData.mockResolvedValue(`${R}${S.slice(2)}1c`);
});

afterEach(() => {
  vi.useRealTimers();
});

describe('permitDeadline', () => {
  it('expires the signature a fixed time from now, in seconds', () => {
    expect(permitDeadline(1_700_000_000_500)).toBe(BigInt(1_700_000_000 + PERMIT_SIGNATURE_TTL_SECONDS));
  });
});

describe('signPermit', () => {
  it("signs the token's Permit over its domain, with the vault as spender and a fresh nonce", async () => {
    const permit = await signPermit({ wallet, domain: DOMAIN, token: TOKEN, spender: VAULT, amount: 100n });

    expect(readContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ address: TOKEN, chainId: 1, functionName: 'nonces', args: [ALICE] }),
    );
    expect(signTypedData).toHaveBeenCalledWith({
      account: wallet.account,
      domain: DOMAIN,
      types: PERMIT_TYPES,
      primaryType: 'Permit',
      message: { owner: ALICE, spender: VAULT, value: 100n, nonce: 7n, deadline: permitDeadline() },
    });
    expect(permit).toEqual({ deadline: permitDeadline(), v: 28, r: R, s: S });
  });

  it('converts a parity-bit recovery id to the 27/28 form permit takes', async () => {
    signTypedData.mockResolvedValue(`${R}${S.slice(2)}01`);

    expect((await signPermit({ wallet, domain: DOMAIN, token: TOKEN, spender: VAULT, amount: 1n })).v).toBe(28);

    signTypedData.mockResolvedValue(`${R}${S.slice(2)}00`);
    expect((await signPermit({ wallet, domain: DOMAIN, token: TOKEN, spender: VAULT, amount: 1n })).v).toBe(27);
  });

  it('refuses without a connected account', async () => {
    await expect(
      signPermit({
        wallet: { signTypedData } as unknown as WalletClient,
        domain: DOMAIN,
        token: TOKEN,
        spender: VAULT,
        amount: 1n,
      }),
    ).rejects.toThrow('Wallet is not connected');
  });
});

describe('signPermit2Transfer', () => {
  it('signs a transfer of exactly the amount to the vault, over the Permit2 domain', async () => {
    const transfer = await signPermit2Transfer({
      wallet,
      chainId: 1,
      permit2: PERMIT2,
      token: TOKEN,
      spender: VAULT,
      amount: 100n,
    });

    expect(signTypedData).toHaveBeenCalledWith({
      account: wallet.account,
      domain: { name: 'Permit2', chainId: 1, verifyingContract: PERMIT2 },
      types: PERMIT2_TYPES,
      primaryType: 'PermitTransferFrom',
      message: {
        permitted: { token: TOKEN, amount: 100n },
        spender: VAULT,
        nonce: transfer.nonce,
        deadline: permitDeadline(),
      },
    });
    expect(transfer.signature).toBe(`${R}${S.slice(2)}1c`);
    expect(transfer.deadline).toBe(permitDeadline());
  });

  it('draws an unordered nonce at random, within uint256', async () => {
    const sign = () =>
      signPermit2Transfer({ wallet, chainId: 1, permit2: PERMIT2, token: TOKEN, spender: VAULT, amount: 1n });
    const [{ nonce: first }, { nonce: second }] = await Promise.all([sign(), sign()]);

    expect(first).not.toBe(second);
    expect(first >= 0n && first <= maxUint256).toBe(true);
  });
});
