/**
 * The account store must follow the wallet, not an RPC.
 *
 * handleAccountChange used to await checkForPausedContracts before account.set, so every
 * reader lagged the wallet by that round trip - and because each event awaits, two
 * overlapping ones (wagmi emits `connecting` then `connected`, and a fast switch back and
 * forth does the same) could commit out of order, the earlier resuming last and writing its
 * stale snapshot over the newer one.
 */
import { get } from 'svelte/store';
import { vi } from 'vitest';

const checkForPausedContracts = vi.fn();
const isSmartContract = vi.fn();

vi.mock('@wagmi/core', () => ({
  getAccount: vi.fn(),
  watchAccount: vi.fn(),
  createConfig: vi.fn(),
  http: vi.fn(),
  reconnect: vi.fn(),
}));
vi.mock('$libs/util/checkForPausedContracts', () => ({
  checkForPausedContracts: (...a: unknown[]) => checkForPausedContracts(...a),
}));
vi.mock('$libs/util/isSmartContract', () => ({ isSmartContract: (...a: unknown[]) => isSmartContract(...a) }));
vi.mock('$libs/util/balance', () => ({ refreshUserBalance: vi.fn() }));
vi.mock('./client', () => ({ config: {}, reconnectionPromise: Promise.resolve() }));

import { account, connectedSmartContractWallet } from '$stores/account';

import { handleAccountChangeForTest as handleAccountChange } from './watcher';

const ADDRESS_A = '0x1111111111111111111111111111111111111111';
const ADDRESS_B = '0x2222222222222222222222222222222222222222';

const flush = async () => await new Promise((resolve) => setTimeout(resolve, 0));

describe('handleAccountChange', () => {
  beforeEach(() => {
    checkForPausedContracts.mockReset().mockResolvedValue(false);
    isSmartContract.mockReset().mockResolvedValue(false);
    account.set(undefined as never);
    connectedSmartContractWallet.set(false);
  });

  it('publishes the account without waiting for the pause check', async () => {
    // Never settles: the store must not be hostage to it
    checkForPausedContracts.mockReturnValue(new Promise(() => {}));

    handleAccountChange({ address: ADDRESS_A, isConnected: true, chainId: 1 } as never);

    expect(get(account)?.address).toBe(ADDRESS_A);
  });

  it('does not let a superseded event overwrite the newer account', async () => {
    // A's smart-wallet check hangs; B's resolves. A used to resume afterwards and commit.
    let resolveA!: (value: boolean) => void;
    isSmartContract.mockReturnValueOnce(new Promise<boolean>((resolve) => (resolveA = resolve)));

    const first = handleAccountChange({ address: ADDRESS_A, isConnected: true, chainId: 1 } as never);
    const second = handleAccountChange({ address: ADDRESS_B, isConnected: true, chainId: 1 } as never);
    await second;

    expect(get(account)?.address).toBe(ADDRESS_B);

    resolveA(true);
    await first;
    await flush();

    // A's classification belongs to an account that is no longer connected
    expect(get(account)?.address).toBe(ADDRESS_B);
    expect(get(connectedSmartContractWallet)).toBe(false);
  });

  it('survives a pause check that rejects', async () => {
    checkForPausedContracts.mockRejectedValue(new Error('rpc down'));

    await handleAccountChange({ address: ADDRESS_A, isConnected: true, chainId: 1 } as never);
    await flush();

    expect(get(account)?.address).toBe(ADDRESS_A);
  });
});

describe('a wallet whose code cannot be read', () => {
  it('is treated as a contract wallet rather than as an EOA', async () => {
    // This flag routes a contract-wallet user through the recipient acknowledgement. A read
    // that failed used to answer "false", skipping the gate for exactly the user it protects.
    isSmartContract.mockRejectedValue(new Error('rpc down'));

    await handleAccountChange({ address: ADDRESS_A, isConnected: true, chainId: 1 } as never);

    expect(get(connectedSmartContractWallet)).toBe(true);
  });
});
