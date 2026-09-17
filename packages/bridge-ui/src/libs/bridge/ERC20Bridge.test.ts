/**
 * The ERC20 send path signs as the wallet it was given, on the chain it was given, and
 * builds the vault call from its arguments alone - not from the connector's current
 * account or the bridge form's stores.
 *
 * Which vault entrypoint it calls is the plan's decision: a standing allowance goes through
 * `sendToken`, an EIP-2612 token through `sendTokenWithPermit`, everything else through
 * `sendTokenWithPermit2` - each with the same operation, wallet, chain and value.
 */
import {
  type Abi,
  type Address,
  ContractFunctionExecutionError,
  ContractFunctionRevertedError,
  encodeErrorResult,
  type Hex,
  MethodNotSupportedRpcError,
  UserRejectedRequestError,
  type WalletClient,
} from 'viem';
import { vi } from 'vitest';

import { erc20VaultAbi } from '$abi';
import { InsufficientAllowanceError, PermitBridgeError, SendERC20Error } from '$libs/error';
import { ALICE, BOB, L1_CHAIN_ID, L2_CHAIN_ID } from '$mocks';

const readContract = vi.fn();
const simulateContract = vi.fn();
const writeContract = vi.fn();
vi.mock('@wagmi/core', () => ({
  readContract: (...args: unknown[]) => readContract(...args),
  simulateContract: (...args: unknown[]) => simulateContract(...args),
  writeContract: (...args: unknown[]) => writeContract(...args),
  getBytecode: vi.fn(),
  getPublicClient: vi.fn(),
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
// The plan and the signers, scripted per test: what they do is pinned in their own tests.
// The failure classification stays real, so what rules a flow out is what the bridge does
const planErc20Send = vi.fn();
const signPermit = vi.fn();
const signPermit2Transfer = vi.fn();
const markPermitUnusable = vi.fn();
vi.mock('./permit', async (importOriginal) => ({
  ...(await importOriginal<typeof import('./permit')>()),
  planErc20Send: (...args: unknown[]) => planErc20Send(...args),
  signPermit: (...args: unknown[]) => signPermit(...args),
  signPermit2Transfer: (...args: unknown[]) => signPermit2Transfer(...args),
  markPermitUnusable: (...args: unknown[]) => markPermitUnusable(...args),
}));

import { destOwnerAddress, gasLimitZero } from '$components/Bridge/state';

import { ERC20Bridge } from './ERC20Bridge';
import { permit2SignatureErrorsAbi, TypedDataSigningError } from './permit';

const TOKEN = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599' as Address;
const VAULT = '0x0000000000000000000000000000000000000456' as Address;
const OTHER = '0x0000000000000000000000000000000000000999' as Address;
const PERMIT2 = '0x000000000022D473030F116dDEE9F6B43aC78BA3' as Address;
const DOMAIN = { name: 'Token', version: '1', chainId: L1_CHAIN_ID, verifyingContract: TOKEN };
const R = `0x${'11'.repeat(32)}` as Hex;
const S = `0x${'22'.repeat(32)}` as Hex;
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
const simulated = () => simulateContract.mock.calls[0][1];

/** A revert the way viem reports it from simulateContract, decoded against the ABI it was called with */
const revertedWith = (abi: Abi, errorName: string) =>
  new ContractFunctionExecutionError(
    new ContractFunctionRevertedError({ abi, data: encodeErrorResult({ abi, errorName }), functionName: 'send' }),
    { abi, functionName: 'send' },
  );

beforeEach(() => {
  vi.clearAllMocks();
  // A standing allowance covers the amount, so the send reaches the plain vault call
  planErc20Send.mockResolvedValue({ method: 'sendToken' });
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

  it('plans the send from its arguments: the signing account, the source chain, the token, the vault, the amount', async () => {
    await new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never);

    expect(planErc20Send).toHaveBeenCalledWith({
      chainId: L1_CHAIN_ID,
      token: TOKEN,
      owner: ALICE,
      vault: VAULT,
      amount: BigInt(5),
    });
  });

  it('refuses to send while the plan still asks for an approval', async () => {
    planErc20Send.mockResolvedValue({
      method: 'approve',
      spender: VAULT,
      amount: BigInt(5),
      currentAllowance: 0n,
      target: 'vault',
    });

    await expect(new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never)).rejects.toBeInstanceOf(
      InsufficientAllowanceError,
    );
    expect(simulateContract).not.toHaveBeenCalled();
  });
});

describe('ERC20Bridge.bridge with a signature', () => {
  it('consumes an EIP-2612 permit signed for the vault, over the amount being sent', async () => {
    planErc20Send.mockResolvedValue({ method: 'permit', domain: DOMAIN });
    signPermit.mockResolvedValue({ deadline: BigInt(1234), v: 28, r: R, s: S });

    await new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never);

    expect(signPermit).toHaveBeenCalledWith({
      wallet,
      domain: DOMAIN,
      token: TOKEN,
      spender: VAULT,
      amount: BigInt(5),
    });
    expect(simulated()).toMatchObject({
      address: VAULT,
      functionName: 'sendTokenWithPermit',
      account: wallet.account,
      chainId: L1_CHAIN_ID,
      value: BigInt(1000),
    });
    const [op, deadline, v, r, s] = simulated().args;
    expect(op).toMatchObject({ token: TOKEN, amount: BigInt(5), to: BOB });
    expect([deadline, v, r, s]).toEqual([BigInt(1234), 28, R, S]);
    expect(writeContract).toHaveBeenCalledWith(expect.anything(), { simulated: true });
  });

  it('pulls through Permit2 with a transfer signed for the vault', async () => {
    planErc20Send.mockResolvedValue({ method: 'permit2', permit2: PERMIT2 });
    signPermit2Transfer.mockResolvedValue({ nonce: BigInt(77), deadline: BigInt(1234), signature: '0xsig' });

    await new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never);

    expect(signPermit2Transfer).toHaveBeenCalledWith({
      wallet,
      chainId: L1_CHAIN_ID,
      permit2: PERMIT2,
      token: TOKEN,
      spender: VAULT,
      amount: BigInt(5),
    });
    expect(simulated()).toMatchObject({
      functionName: 'sendTokenWithPermit2',
      account: wallet.account,
      chainId: L1_CHAIN_ID,
    });
    const [op, nonce, deadline, signature] = simulated().args;
    expect(op).toMatchObject({ token: TOKEN, amount: BigInt(5) });
    expect([nonce, deadline, signature]).toEqual([BigInt(77), BigInt(1234), '0xsig']);
  });

  it('rules the permit flow out when the vault finds no allowance behind the signature, and says so', async () => {
    // A token whose permit verifies something other than the standard message passes the
    // probes and reverts in the vault; from here on the plan offers the next flow
    planErc20Send.mockResolvedValue({ method: 'permit', domain: DOMAIN });
    signPermit.mockResolvedValue({ deadline: BigInt(1234), v: 28, r: R, s: S });
    simulateContract.mockRejectedValue(revertedWith(erc20VaultAbi, 'VAULT_PERMIT_NO_ALLOWANCE'));

    await expect(new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never)).rejects.toBeInstanceOf(
      PermitBridgeError,
    );
    expect(markPermitUnusable).toHaveBeenCalledWith(L1_CHAIN_ID, TOKEN, 'permit');
    expect(markPermitUnusable).toHaveBeenCalledTimes(1);
  });

  it('rules the Permit2 flow out when Permit2 refuses the signature', async () => {
    planErc20Send.mockResolvedValue({ method: 'permit2', permit2: PERMIT2 });
    signPermit2Transfer.mockResolvedValue({ nonce: BigInt(77), deadline: BigInt(1234), signature: '0xsig' });
    // Permit2's error data reaches viem unchanged through the vault; it decodes by name only
    // because the send is simulated against the vault ABI with Permit2's errors alongside
    const sendAbi = [...erc20VaultAbi, ...permit2SignatureErrorsAbi];
    simulateContract.mockRejectedValue(revertedWith(sendAbi, 'InvalidSigner'));

    await expect(new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never)).rejects.toBeInstanceOf(
      PermitBridgeError,
    );
    expect(markPermitUnusable).toHaveBeenCalledWith(L1_CHAIN_ID, TOKEN, 'permit2');
    expect((simulated().abi as Abi).some((item) => item.type === 'error' && item.name === 'InvalidSigner')).toBe(true);
  });

  it('rules both signed flows out for a wallet that cannot sign typed data', async () => {
    planErc20Send.mockResolvedValue({ method: 'permit', domain: DOMAIN });
    signPermit.mockRejectedValue(
      new TypedDataSigningError(new MethodNotSupportedRpcError(new Error('eth_signTypedData_v4 is not available'))),
    );

    await expect(new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never)).rejects.toBeInstanceOf(
      PermitBridgeError,
    );
    expect(markPermitUnusable).toHaveBeenCalledWith(L1_CHAIN_ID, TOKEN, 'permit');
    expect(markPermitUnusable).toHaveBeenCalledWith(L1_CHAIN_ID, TOKEN, 'permit2');
  });

  it('keeps a signed flow open on a failure a retry may fix, reporting it as the plain failure', async () => {
    planErc20Send.mockResolvedValue({ method: 'permit', domain: DOMAIN });
    signPermit.mockResolvedValue({ deadline: BigInt(1234), v: 28, r: R, s: S });
    const bridge = () => new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never);

    // The RPC, not the chain
    simulateContract.mockRejectedValueOnce(new Error('rpc rate limited'));
    await expect(bridge()).rejects.toBeInstanceOf(SendERC20Error);
    // A revert a plain send fails on too
    simulateContract.mockRejectedValueOnce(revertedWith(erc20VaultAbi, 'VAULT_INVALID_TO_ADDR'));
    await expect(bridge()).rejects.toBeInstanceOf(SendERC20Error);
    // Missing gas money, after a simulation that passed
    simulateContract.mockResolvedValueOnce({ request: { simulated: true } });
    writeContract.mockRejectedValueOnce(new Error('insufficient funds for gas * price + value'));
    await expect(bridge()).rejects.toBeInstanceOf(SendERC20Error);

    expect(markPermitUnusable).not.toHaveBeenCalled();
  });

  it('reports a declined signature prompt as a rejection, not as a flow that does not work', async () => {
    planErc20Send.mockResolvedValue({ method: 'permit2', permit2: PERMIT2 });
    signPermit2Transfer.mockRejectedValue(new UserRejectedRequestError(new Error('User rejected the request.')));

    await expect(new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never)).rejects.toBeInstanceOf(
      UserRejectedRequestError,
    );
    expect(markPermitUnusable).not.toHaveBeenCalled();
    expect(simulateContract).not.toHaveBeenCalled();
  });

  it('keeps the plain failure for a plain send', async () => {
    simulateContract.mockRejectedValue(new Error('boom'));

    await expect(new ERC20Bridge({} as never).bridge({ ...args, gasLimitZero: false } as never)).rejects.toBeInstanceOf(
      SendERC20Error,
    );
    expect(markPermitUnusable).not.toHaveBeenCalled();
  });
});
