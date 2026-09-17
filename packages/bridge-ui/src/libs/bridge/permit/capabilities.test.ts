/**
 * What the permit flows can rely on is read off the chain, never assumed: a vault has the
 * entrypoints only once its proxy is upgraded, Permit2 has code on a chain only once it is
 * deployed there, and a token's permit is usable only if the domain this UI would sign over is
 * the one the token verifies.
 */
import {
  type Address,
  BaseError,
  ContractFunctionExecutionError,
  ContractFunctionRevertedError,
  domainSeparator,
  ExecutionRevertedError,
  HttpRequestError,
} from 'viem';
import { vi } from 'vitest';

import { ALICE, BOB } from '$mocks';

const readContract = vi.fn();
const getBytecode = vi.fn();
vi.mock('@wagmi/core', () => ({
  readContract: (...args: unknown[]) => readContract(...args),
  getBytecode: (...args: unknown[]) => getBytecode(...args),
}));
vi.mock('$libs/wagmi', () => ({ config: {} }));

import {
  getPermitDomain,
  getVaultPermit2,
  isPermit2Deployed,
  isPermitUnusable,
  markPermitUnusable,
  resetPermitCapabilities,
} from './capabilities';

const VAULT = '0x1000010000000000000000000000000000000002' as Address;
const PERMIT2 = '0x000000000022D473030F116dDEE9F6B43aC78BA3' as Address;
const OTHER = '0x0000000000000000000000000000000000000999' as Address;
const TOKEN = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599' as Address;
const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F' as Address;
const CHAIN = 1;

/** How viem reports a readContract failure: always this wrapper, the cause telling them apart */
const readFailure = (cause: BaseError, functionName = 'PERMIT2') =>
  new ContractFunctionExecutionError(cause, { abi: [], functionName });
/** A revert as viem reports one: the node's wording as the reason, no data to decode */
const contractRevert = (functionName = 'PERMIT2') =>
  readFailure(
    new ContractFunctionRevertedError({ abi: [], functionName, message: 'execution reverted' }),
    functionName,
  );
/** A revert the node returned without data, as geth does for an empty revert */
const bareRevert = () => readFailure(new ExecutionRevertedError({ message: 'execution reverted' }));
/** The RPC could not be reached at all */
const transportFailure = () =>
  readFailure(new HttpRequestError({ url: 'https://l1.rpc', details: 'fetch failed', body: {} }));

/** Scripts readContract by function name, for the many-read probes; a function not listed reverts */
const answer = (answers: Record<string, unknown>) => {
  readContract.mockImplementation(async (_config: unknown, { functionName }: { functionName: string }) => {
    if (!(functionName in answers)) throw contractRevert(functionName);
    const value = answers[functionName];
    if (value instanceof Error) throw value;
    return value;
  });
};

beforeEach(() => {
  vi.clearAllMocks();
  resetPermitCapabilities();
});

describe('getVaultPermit2', () => {
  it('reports the Permit2 an upgraded vault pulls through', async () => {
    readContract.mockResolvedValue(PERMIT2);

    expect(await getVaultPermit2(CHAIN, VAULT)).toBe(PERMIT2);
    expect(readContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ address: VAULT, chainId: CHAIN, functionName: 'PERMIT2' }),
    );
  });

  it('reports no support for a vault that names anything but the canonical Permit2', async () => {
    // The answer becomes the spender of an unlimited approval, so it is never taken from the
    // RPC: only the canonical address, which the vault holds as a constant, is accepted
    for (const answer of ['0x0000000000000000000000000000000000000000', OTHER]) {
      resetPermitCapabilities();
      readContract.mockResolvedValue(answer);

      expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();
      // Remembered like any other answer from the contract
      readContract.mockResolvedValue(PERMIT2);
      expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();
    }
  });

  it('reports the canonical address in its canonical casing, whatever casing the read used', async () => {
    readContract.mockResolvedValue(PERMIT2.toLowerCase());

    expect(await getVaultPermit2(CHAIN, VAULT)).toBe(PERMIT2);
  });

  it("reports no support for today's vaults, whose implementation reverts the read", async () => {
    readContract.mockRejectedValue(contractRevert());

    expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();
  });

  it('reads a bare revert the same way', async () => {
    readContract.mockRejectedValueOnce(bareRevert());
    expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();

    // And remembers it: the answer came from the contract
    readContract.mockResolvedValue(PERMIT2);
    expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();
  });

  it('asks a vault once per chain, whichever way it answered', async () => {
    readContract.mockRejectedValueOnce(contractRevert());
    expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();

    readContract.mockResolvedValue(PERMIT2);
    // Still the cached answer: a proxy does not grow the entrypoints mid-session
    expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();
    expect(await getVaultPermit2(2, VAULT)).toBe(PERMIT2);
    expect(readContract).toHaveBeenCalledTimes(2);
  });

  it('does not remember a transport failure as an answer', async () => {
    readContract.mockRejectedValueOnce(transportFailure());
    expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();

    readContract.mockResolvedValue(PERMIT2);
    expect(await getVaultPermit2(CHAIN, VAULT)).toBe(PERMIT2);
  });
});

describe('isPermit2Deployed', () => {
  it('is true only where there is code at the address', async () => {
    getBytecode.mockResolvedValueOnce('0x6080');
    expect(await isPermit2Deployed(CHAIN, PERMIT2)).toBe(true);

    getBytecode.mockResolvedValueOnce('0x');
    expect(await isPermit2Deployed(2, PERMIT2)).toBe(false);

    getBytecode.mockResolvedValueOnce(undefined);
    expect(await isPermit2Deployed(3, PERMIT2)).toBe(false);
  });

  it('treats an unreadable chain as not deployed, without remembering it', async () => {
    getBytecode.mockRejectedValueOnce(new Error('rpc down'));
    expect(await isPermit2Deployed(CHAIN, PERMIT2)).toBe(false);

    getBytecode.mockResolvedValueOnce('0x6080');
    expect(await isPermit2Deployed(CHAIN, PERMIT2)).toBe(true);
  });

  it('reads the code once per chain', async () => {
    getBytecode.mockResolvedValue('0x6080');
    await isPermit2Deployed(CHAIN, PERMIT2);
    await isPermit2Deployed(CHAIN, PERMIT2);

    expect(getBytecode).toHaveBeenCalledTimes(1);
  });
});

describe('getPermitDomain', () => {
  const separatorFor = (name: string, version: string) =>
    domainSeparator({ domain: { name, version, chainId: CHAIN, verifyingContract: TOKEN } });

  it('takes the domain a token states through ERC-5267 when it hashes to its separator', async () => {
    answer({
      DOMAIN_SEPARATOR: separatorFor('USD Coin', '2'),
      nonces: 0n,
      eip712Domain: ['0x0f', 'USD Coin', '2', BigInt(CHAIN), TOKEN, `0x${'00'.repeat(32)}`, []],
    });

    expect(await getPermitDomain(CHAIN, TOKEN, ALICE)).toEqual({
      name: 'USD Coin',
      version: '2',
      chainId: CHAIN,
      verifyingContract: TOKEN,
    });
  });

  it('falls back to the name with the versions in circulation', async () => {
    // USDC: no ERC-5267, domain version "2" while the token's name is what name() says
    answer({ DOMAIN_SEPARATOR: separatorFor('USD Coin', '2'), nonces: 3n, name: 'USD Coin' });

    expect(await getPermitDomain(CHAIN, TOKEN, ALICE)).toMatchObject({ name: 'USD Coin', version: '2' });
  });

  it('refuses a token whose separator matches no domain it could sign over', async () => {
    // A signature over the wrong domain is one the token rejects, after the user signed it
    answer({ DOMAIN_SEPARATOR: separatorFor('Something Else', '7'), nonces: 0n, name: 'Token' });

    expect(await getPermitDomain(CHAIN, TOKEN, ALICE)).toBeNull();
  });

  it('refuses a token without nonces or DOMAIN_SEPARATOR', async () => {
    answer({ DOMAIN_SEPARATOR: separatorFor('Token', '1'), name: 'Token' }); // no nonces
    expect(await getPermitDomain(CHAIN, TOKEN, ALICE)).toBeNull();

    resetPermitCapabilities();
    answer({ nonces: 0n, name: 'Token' }); // no DOMAIN_SEPARATOR
    expect(await getPermitDomain(CHAIN, TOKEN, ALICE)).toBeNull();
  });

  it('refuses a denylisted token before reading anything', async () => {
    // Mainnet DAI has nonces and a separator, and a permit the vault cannot call
    expect(await getPermitDomain(CHAIN, DAI, ALICE)).toBeNull();
    expect(readContract).not.toHaveBeenCalled();
  });

  it('leaves a read the RPC failed to the caller, and remembers nothing from it', async () => {
    // A null kept from a transport failure would route an EIP-2612 token to Permit2, and its
    // user into an approval, for the rest of the session
    answer({ DOMAIN_SEPARATOR: transportFailure(), nonces: 0n, name: 'Token' });
    await expect(getPermitDomain(CHAIN, TOKEN, ALICE)).rejects.toThrow();

    answer({ DOMAIN_SEPARATOR: separatorFor('Token', '1'), nonces: 0n, name: transportFailure() });
    await expect(getPermitDomain(CHAIN, TOKEN, ALICE)).rejects.toThrow();

    // The ERC-5267 read too: swallowed, it fell through to the name guesses and cached a null
    answer({
      DOMAIN_SEPARATOR: separatorFor('Token', '3'),
      nonces: 0n,
      eip712Domain: transportFailure(),
      name: 'Token',
    });
    await expect(getPermitDomain(CHAIN, TOKEN, ALICE)).rejects.toThrow();

    answer({ DOMAIN_SEPARATOR: separatorFor('Token', '1'), nonces: 0n, name: 'Token' });
    expect(await getPermitDomain(CHAIN, TOKEN, ALICE)).toMatchObject({ name: 'Token', version: '1' });
  });

  it('keeps the domain per token and chain', async () => {
    answer({ DOMAIN_SEPARATOR: separatorFor('Token', '1'), nonces: 0n, name: 'Token' });
    await getPermitDomain(CHAIN, TOKEN, ALICE);
    const reads = readContract.mock.calls.length;

    await getPermitDomain(CHAIN, TOKEN, ALICE);
    expect(readContract).toHaveBeenCalledTimes(reads);
  });
});

describe('markPermitUnusable', () => {
  it('rules one flow out for one wallet and one token on one chain', () => {
    markPermitUnusable(CHAIN, TOKEN, ALICE, 'permit');

    expect(isPermitUnusable(CHAIN, TOKEN, ALICE, 'permit')).toBe(true);
    expect(isPermitUnusable(CHAIN, TOKEN, ALICE, 'permit2')).toBe(false);
    expect(isPermitUnusable(2, TOKEN, ALICE, 'permit')).toBe(false);
    // Another wallet may sign perfectly well: what was ruled out was this one's signing
    expect(isPermitUnusable(CHAIN, TOKEN, BOB, 'permit')).toBe(false);
    expect(isPermitUnusable(CHAIN, TOKEN.toLowerCase() as Address, ALICE.toLowerCase() as Address, 'permit')).toBe(
      true,
    );
  });
});
