/**
 * The typed data is what the contracts verify: an EIP-2612 permit over the token's own domain
 * naming the vault as spender, and a Permit2 transfer of exactly the amount to the vault.
 */
import {
  type Address,
  concatHex,
  encodeAbiParameters,
  hashTypedData,
  type Hex,
  keccak256,
  maxUint256,
  parseAbiParameters,
  toHex,
  type WalletClient,
} from 'viem';
import { vi } from 'vitest';

import { ALICE } from '$mocks';

const readContract = vi.fn();
const getBlock = vi.fn();
vi.mock('@wagmi/core', () => ({
  readContract: (...args: unknown[]) => readContract(...args),
  getBlock: (...args: unknown[]) => getBlock(...args),
}));
vi.mock('$libs/wagmi', () => ({ config: {} }));

import { PERMIT_SIGNATURE_TTL_SECONDS } from './constants';
import {
  PERMIT_TYPES,
  PERMIT2_TYPES,
  permitDeadline,
  signPermit,
  signPermit2Transfer,
  TypedDataSigningError,
} from './signatures';

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
  // The chain's clock agrees with the local one here; the cases below move it
  getBlock.mockResolvedValue({ timestamp: 1_700_000_000n });
  signTypedData.mockResolvedValue(`${R}${S.slice(2)}1c`);
});

/** keccak256(0x1901 ‖ domainSeparator ‖ structHash), from the EIP-712 and Permit2 type strings themselves */
const digestOf = (domainSeparator: Hex, structHash: Hex) =>
  keccak256(concatHex(['0x1901', domainSeparator, structHash]));
const typeHash = (type: string) => keccak256(toHex(type));

afterEach(() => {
  vi.useRealTimers();
});

describe('permitDeadline', () => {
  it('expires the signature a fixed time from now, in seconds', () => {
    expect(permitDeadline(1_700_000_000_500)).toBe(BigInt(1_700_000_000 + PERMIT_SIGNATURE_TTL_SECONDS));
  });
});

describe('the typed data', () => {
  it('lists the fields of both types in the order the contracts hash them', () => {
    // Field order is the typehash: reordered, a signature reverts as VAULT_PERMIT_NO_ALLOWANCE
    // or InvalidSigner, which the send would read as a verdict on the token
    expect(PERMIT_TYPES).toEqual({
      Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
      ],
    });
    expect(PERMIT2_TYPES).toEqual({
      PermitTransferFrom: [
        { name: 'permitted', type: 'TokenPermissions' },
        { name: 'spender', type: 'address' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
      ],
      TokenPermissions: [
        { name: 'token', type: 'address' },
        { name: 'amount', type: 'uint256' },
      ],
    });
  });

  it('hashes an EIP-2612 permit to the digest the token computes', async () => {
    await signPermit({ wallet, domain: DOMAIN, token: TOKEN, spender: VAULT, amount: 100n });
    const signed = signTypedData.mock.calls[0][0];

    const domainSeparator = keccak256(
      encodeAbiParameters(parseAbiParameters('bytes32, bytes32, bytes32, uint256, address'), [
        typeHash('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
        keccak256(toHex(DOMAIN.name)),
        keccak256(toHex(DOMAIN.version)),
        BigInt(DOMAIN.chainId),
        DOMAIN.verifyingContract,
      ]),
    );
    const structHash = keccak256(
      encodeAbiParameters(parseAbiParameters('bytes32, address, address, uint256, uint256, uint256'), [
        typeHash('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'),
        ALICE,
        VAULT,
        100n,
        7n,
        permitDeadline(),
      ]),
    );
    expect(hashTypedData(signed)).toBe(digestOf(domainSeparator, structHash));
  });

  it('hashes a Permit2 transfer to the digest Permit2 computes, with the vault as spender', async () => {
    const { nonce } = await signPermit2Transfer({
      wallet,
      chainId: 1,
      permit2: PERMIT2,
      token: TOKEN,
      spender: VAULT,
      amount: 100n,
    });
    const signed = signTypedData.mock.calls[0][0];

    const domainSeparator = keccak256(
      encodeAbiParameters(parseAbiParameters('bytes32, bytes32, uint256, address'), [
        typeHash('EIP712Domain(string name,uint256 chainId,address verifyingContract)'),
        keccak256(toHex('Permit2')),
        1n,
        PERMIT2,
      ]),
    );
    const permittedHash = keccak256(
      encodeAbiParameters(parseAbiParameters('bytes32, address, uint256'), [
        typeHash('TokenPermissions(address token,uint256 amount)'),
        TOKEN,
        100n,
      ]),
    );
    const structHash = keccak256(
      encodeAbiParameters(parseAbiParameters('bytes32, bytes32, address, uint256, uint256'), [
        typeHash(
          'PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)',
        ),
        permittedHash,
        VAULT,
        nonce,
        permitDeadline(),
      ]),
    );
    expect(hashTypedData(signed)).toBe(digestOf(domainSeparator, structHash));
  });
});

describe('the deadline', () => {
  it("comes from the chain's clock, not the wallet's machine", async () => {
    // A machine half an hour slow would sign a deadline the chain sees as already past
    getBlock.mockResolvedValue({ timestamp: 1_700_009_000n });

    const { deadline } = await signPermit({ wallet, domain: DOMAIN, token: TOKEN, spender: VAULT, amount: 1n });

    expect(getBlock).toHaveBeenCalledWith(expect.anything(), { chainId: 1 });
    expect(deadline).toBe(1_700_009_000n + BigInt(PERMIT_SIGNATURE_TTL_SECONDS));
  });

  it('falls back to the local clock when the block cannot be read', async () => {
    getBlock.mockRejectedValue(new Error('rpc down'));

    const { deadline } = await signPermit2Transfer({
      wallet,
      chainId: 1,
      permit2: PERMIT2,
      token: TOKEN,
      spender: VAULT,
      amount: 1n,
    });

    expect(deadline).toBe(permitDeadline());
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

  it("reports a signature the wallet did not produce, with the wallet's error as the cause", async () => {
    const walletError = new Error('eth_signTypedData_v4 is not available');
    signTypedData.mockRejectedValue(walletError);

    const failure = await signPermit({ wallet, domain: DOMAIN, token: TOKEN, spender: VAULT, amount: 1n }).catch(
      (error) => error,
    );

    expect(failure).toBeInstanceOf(TypedDataSigningError);
    expect(failure.cause).toBe(walletError);
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

  it('gives Permit2 a v of 27 or 28, whatever form the wallet reported it in', async () => {
    // Permit2 hands v straight to ecrecover; a parity bit is refused as InvalidSignature, which
    // the send would blame on the token
    const sign = () =>
      signPermit2Transfer({ wallet, chainId: 1, permit2: PERMIT2, token: TOKEN, spender: VAULT, amount: 1n });

    signTypedData.mockResolvedValue(`${R}${S.slice(2)}00`);
    expect((await sign()).signature).toBe(`${R}${S.slice(2)}1b`);
    signTypedData.mockResolvedValue(`${R}${S.slice(2)}01`);
    expect((await sign()).signature).toBe(`${R}${S.slice(2)}1c`);
    // Already in that form, or 64 bytes for Permit2 to handle itself: untouched
    signTypedData.mockResolvedValue(`${R}${S.slice(2)}1b`);
    expect((await sign()).signature).toBe(`${R}${S.slice(2)}1b`);
    signTypedData.mockResolvedValue(`${R}${S.slice(2)}`);
    expect((await sign()).signature).toBe(`${R}${S.slice(2)}`);
  });

  it('draws an unordered nonce at random, within uint256', async () => {
    const sign = () =>
      signPermit2Transfer({ wallet, chainId: 1, permit2: PERMIT2, token: TOKEN, spender: VAULT, amount: 1n });
    const [{ nonce: first }, { nonce: second }] = await Promise.all([sign(), sign()]);

    expect(first).not.toBe(second);
    expect(first >= 0n && first <= maxUint256).toBe(true);
  });
});
