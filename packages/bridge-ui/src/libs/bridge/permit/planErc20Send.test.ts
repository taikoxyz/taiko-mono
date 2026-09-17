/**
 * The plan is what both the buttons and the send are driven off, so its order is the
 * product's order: spend a standing allowance, keep the old flow where nothing better is
 * possible, sign a permit where the token has one, sign through Permit2 for the rest.
 */
import { type Address, maxUint256 } from 'viem';
import { vi } from 'vitest';

import { ALICE } from '$mocks';

const readContract = vi.fn();
vi.mock('@wagmi/core', () => ({ readContract: (...args: unknown[]) => readContract(...args) }));
vi.mock('$libs/wagmi', () => ({ config: {} }));
const isSmartContract = vi.fn();
vi.mock('$libs/util/isSmartContract', () => ({ isSmartContract: (...args: unknown[]) => isSmartContract(...args) }));
const getVaultPermit2 = vi.fn();
const getPermitDomain = vi.fn();
const isPermit2Deployed = vi.fn();
const isPermitUnusable = vi.fn();
vi.mock('./capabilities', () => ({
  getVaultPermit2: (...args: unknown[]) => getVaultPermit2(...args),
  getPermitDomain: (...args: unknown[]) => getPermitDomain(...args),
  isPermit2Deployed: (...args: unknown[]) => isPermit2Deployed(...args),
  isPermitUnusable: (...args: unknown[]) => isPermitUnusable(...args),
}));

import { planErc20Send } from './planErc20Send';

const VAULT = '0x1000010000000000000000000000000000000002' as Address;
const PERMIT2 = '0x000000000022D473030F116dDEE9F6B43aC78BA3' as Address;
const TOKEN = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599' as Address;
const DOMAIN = { name: 'Token', version: '1', chainId: 1, verifyingContract: TOKEN };
const args = { chainId: 1, token: TOKEN, owner: ALICE, vault: VAULT, amount: 100n };

/** Scripts the two allowance reads by spender */
const allowances = ({ vault = 0n, permit2 = 0n }: { vault?: bigint; permit2?: bigint }) => {
  readContract.mockImplementation(async (_config: unknown, { args: [, spender] }: { args: [Address, Address] }) =>
    spender === VAULT ? vault : permit2,
  );
};

beforeEach(() => {
  vi.clearAllMocks();
  allowances({});
  getVaultPermit2.mockResolvedValue(PERMIT2);
  isSmartContract.mockResolvedValue(false);
  getPermitDomain.mockResolvedValue(null);
  isPermit2Deployed.mockResolvedValue(true);
  isPermitUnusable.mockReturnValue(false);
});

describe('planErc20Send', () => {
  it('spends a standing vault allowance without asking anything else', async () => {
    allowances({ vault: 100n });

    expect(await planErc20Send(args)).toEqual({ method: 'sendToken' });
    expect(getVaultPermit2).not.toHaveBeenCalled();
  });

  it('keeps the exact-amount vault approval on a vault without permit support', async () => {
    getVaultPermit2.mockResolvedValue(null);

    expect(await planErc20Send(args)).toEqual({
      method: 'approve',
      spender: VAULT,
      amount: 100n,
      currentAllowance: 0n,
      target: 'vault',
    });
    expect(getPermitDomain).not.toHaveBeenCalled();
  });

  it('keeps the vault approval for a contract wallet', async () => {
    // permit recovers an ECDSA signer, which a contract wallet is not
    isSmartContract.mockResolvedValue(true);
    getPermitDomain.mockResolvedValue(DOMAIN);

    expect(await planErc20Send(args)).toMatchObject({ method: 'approve', target: 'vault' });
    expect(isSmartContract).toHaveBeenCalledWith(ALICE, 1);
  });

  it('keeps the vault approval when the wallet code cannot be read, rather than failing the plan', async () => {
    // The plain approval is what every wallet got before; an RPC blip is not a reason to
    // fail the status read, and the safe assumption about an unreadable wallet is "contract"
    isSmartContract.mockRejectedValue(new Error('rpc down'));
    getPermitDomain.mockResolvedValue(DOMAIN);

    expect(await planErc20Send(args)).toMatchObject({ method: 'approve', target: 'vault' });
  });

  it('signs an EIP-2612 permit for a token that has one', async () => {
    getPermitDomain.mockResolvedValue(DOMAIN);
    allowances({ permit2: maxUint256 }); // an open Permit2 allowance changes nothing

    expect(await planErc20Send(args)).toEqual({ method: 'permit', domain: DOMAIN });
    expect(getPermitDomain).toHaveBeenCalledWith(1, TOKEN, ALICE);
  });

  it('signs through Permit2 when it already holds an allowance', async () => {
    allowances({ permit2: 100n });

    expect(await planErc20Send(args)).toEqual({ method: 'permit2', permit2: PERMIT2 });
  });

  it('asks for one unlimited Permit2 approval otherwise', async () => {
    allowances({ permit2: 40n });

    expect(await planErc20Send(args)).toEqual({
      method: 'approve',
      spender: PERMIT2,
      amount: maxUint256,
      currentAllowance: 40n,
      target: 'permit2',
    });
  });

  it('falls back to the vault approval where Permit2 has no code', async () => {
    isPermit2Deployed.mockResolvedValue(false);

    expect(await planErc20Send(args)).toMatchObject({ method: 'approve', spender: VAULT, target: 'vault' });
  });

  it('skips a flow the chain already rejected for the token', async () => {
    getPermitDomain.mockResolvedValue(DOMAIN);
    allowances({ permit2: 100n });
    isPermitUnusable.mockImplementation(
      (_chainId: number, _token: Address, _owner: Address, method: string) => method === 'permit',
    );

    expect(await planErc20Send(args)).toEqual({ method: 'permit2', permit2: PERMIT2 });
    expect(getPermitDomain).not.toHaveBeenCalled();
    // Asked for this wallet: what was ruled out was its signing, not the token's
    expect(isPermitUnusable).toHaveBeenCalledWith(1, TOKEN, ALICE, 'permit');

    isPermitUnusable.mockReturnValue(true);
    expect(await planErc20Send(args)).toMatchObject({ method: 'approve', target: 'vault' });
  });
});
