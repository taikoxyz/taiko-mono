/**
 * The ERC20 send path signs as the wallet it was given, on the chain it was given, and
 * builds the vault call from its arguments alone - not from the connector's current
 * account or the bridge form's stores.
 */
import type { Address, WalletClient } from 'viem';
import { vi } from 'vitest';

import { ALICE, BOB, L1_CHAIN_ID, L2_CHAIN_ID } from '$mocks';

const readContract = vi.fn();
const simulateContract = vi.fn();
const writeContract = vi.fn();
vi.mock('@wagmi/core', () => ({
  readContract: (...args: unknown[]) => readContract(...args),
  simulateContract: (...args: unknown[]) => simulateContract(...args),
  writeContract: (...args: unknown[]) => writeContract(...args),
}));
vi.mock('$libs/wagmi', () => ({ config: {} }));
vi.mock('$bridgeConfig');
vi.mock('viem', async (importOriginal) => ({
  ...(await importOriginal<typeof import('viem')>()),
  getContract: ({ address }: { address: Address }) => ({ address }),
}));
const estimateMessageGasLimit = vi.fn();
vi.mock('./estimateMessageGasLimit', () => ({
  estimateMessageGasLimitWithMinimum: (...args: unknown[]) => estimateMessageGasLimit(...args),
}));
vi.mock('$libs/util/checkForPausedContracts', () => ({ isBridgePaused: vi.fn().mockResolvedValue(false) }));
vi.mock('$libs/util/getConnectedWallet', () => ({
  getConnectedWallet: vi.fn().mockResolvedValue({ chain: { id: 1 } }),
}));

import { destOwnerAddress, gasLimitZero } from '$components/Bridge/state';

import { ERC20Bridge } from './ERC20Bridge';

const TOKEN = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599' as Address;
const VAULT = '0x0000000000000000000000000000000000000456' as Address;
const OTHER = '0x0000000000000000000000000000000000000999' as Address;
const wallet = { account: { address: ALICE }, chain: { id: L1_CHAIN_ID } } as unknown as WalletClient;
const args = {
  to: BOB as Address,
  wallet,
  srcChainId: L1_CHAIN_ID,
  destChainId: L2_CHAIN_ID,
  fee: BigInt(1000),
  amount: BigInt(5),
  token: TOKEN,
  tokenVaultAddress: VAULT,
  isTokenAlreadyDeployed: true,
  tokenObject: { type: 'ERC20', symbol: 'USDC', decimals: 6, addresses: {} },
};

const sentOp = () => simulateContract.mock.calls[0][1].args[0];

beforeEach(() => {
  vi.clearAllMocks();
  // An allowance that covers the amount, so the send reaches the vault call
  readContract.mockResolvedValue(BigInt(10));
  estimateMessageGasLimit.mockResolvedValue({ gasLimit: 1_000_000, minGasLimit: 100_000 });
  simulateContract.mockResolvedValue({ request: { simulated: true } });
  writeContract.mockResolvedValue('0xtx');
  // The form holds values the arguments do not, so any read of it shows up in what gets sent
  destOwnerAddress.set(OTHER);
  gasLimitZero.set(true);
});

describe('ERC20Bridge.bridge', () => {
  it('simulates and writes as the wallet it was given, on the source chain', async () => {
    await new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never);

    expect(simulateContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ functionName: 'sendToken', account: wallet.account, chainId: L1_CHAIN_ID }),
    );
    expect(writeContract).toHaveBeenCalledWith(expect.anything(), { simulated: true });
  });

  it('takes the destination owner and the gas option from its arguments, never from the form', async () => {
    await new ERC20Bridge({} as never).bridge({ ...args, destOwner: ALICE, gasLimitZero: false } as never);

    const op = sentOp();
    expect(op.destOwner).toBe(ALICE);
    expect(op.gasLimit).toBe(1_000_000);
    expect(op.fee).toBe(BigInt(1000));
  });
});
