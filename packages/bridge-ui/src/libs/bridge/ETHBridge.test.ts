/**
 * The ETH send path signs as the wallet it was given, on the chain it was given, and builds
 * its message from its arguments alone. It used to take the chain from whatever wallet was
 * connected at the time of the write and sign with the connector's current account, and to
 * read the destination owner and the zero-gas option from the bridge form's stores - so an
 * account or option changed during preparation reached the transaction but not its record.
 */
import type { Address, WalletClient } from 'viem';
import { vi } from 'vitest';

import { ALICE, BOB, L1_CHAIN_ID, L2_CHAIN_ID } from '$mocks';

const simulateContract = vi.fn();
const writeContract = vi.fn();
const getWalletClient = vi.fn();
vi.mock('@wagmi/core', () => ({
  simulateContract: (...args: unknown[]) => simulateContract(...args),
  writeContract: (...args: unknown[]) => writeContract(...args),
  getWalletClient: (...args: unknown[]) => getWalletClient(...args),
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

import { destOwnerAddress, gasLimitZero } from '$components/Bridge/state';

import { ETHBridge } from './ETHBridge';

const BRIDGE = '0x0000000000000000000000000000000000000b1d' as Address;
const OTHER = '0x0000000000000000000000000000000000000999' as Address;
const wallet = { account: { address: ALICE }, chain: { id: L1_CHAIN_ID } } as unknown as WalletClient;
const args = {
  to: BOB as Address,
  wallet,
  srcChainId: L1_CHAIN_ID,
  destChainId: L2_CHAIN_ID,
  fee: BigInt(1000),
  amount: BigInt(5),
  bridgeAddress: BRIDGE,
  tokenObject: { type: 'ETH', symbol: 'ETH', decimals: 18, addresses: {} },
};

const sentMessage = () => simulateContract.mock.calls[0][1].args[0];

beforeEach(() => {
  vi.clearAllMocks();
  estimateMessageGasLimit.mockResolvedValue({ gasLimit: 1_000_000, minGasLimit: 100_000 });
  simulateContract.mockResolvedValue({ request: { simulated: true } });
  writeContract.mockResolvedValue('0xtx');
  // The connected wallet and the form hold values the arguments do not, so any read of
  // either shows up in what gets sent
  getWalletClient.mockResolvedValue({ chain: { id: L2_CHAIN_ID } });
  destOwnerAddress.set(OTHER);
  gasLimitZero.set(true);
});

describe('ETHBridge.bridge', () => {
  it('simulates and writes as the wallet it was given, on the source chain', async () => {
    await new ETHBridge({} as never).bridge({ ...args, gasLimitZero: false } as never);

    expect(simulateContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ functionName: 'sendMessage', account: wallet.account, chainId: L1_CHAIN_ID }),
    );
    expect(writeContract).toHaveBeenCalledWith(expect.anything(), { simulated: true });
    expect(getWalletClient).not.toHaveBeenCalled();
  });

  it('takes the destination owner and the gas option from its arguments, never from the form', async () => {
    await new ETHBridge({} as never).bridge({ ...args, destOwner: ALICE, gasLimitZero: false } as never);

    const message = sentMessage();
    expect(message.destOwner).toBe(ALICE);
    expect(message.gasLimit).toBe(1_000_000);
    expect(message.fee).toBe(BigInt(1000));
  });

  it('sends a zero gas limit with no fee when asked to', async () => {
    await new ETHBridge({} as never).bridge({ ...args, gasLimitZero: true } as never);

    const message = sentMessage();
    expect(message.gasLimit).toBe(0);
    expect(message.fee).toBe(BigInt(0));
    expect(estimateMessageGasLimit).not.toHaveBeenCalled();
  });

  it('defaults the destination owner to the recipient', async () => {
    await new ETHBridge({} as never).bridge({ ...args, gasLimitZero: false } as never);

    expect(sentMessage().destOwner).toBe(BOB);
  });
});
