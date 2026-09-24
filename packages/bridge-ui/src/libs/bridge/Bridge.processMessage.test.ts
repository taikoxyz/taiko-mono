/**
 * The claim / retry / release paths shared by every bridge. These are the calls that move
 * funds on the destination or source chain after a send, and nothing exercised them: the
 * preconditions, which status routes to which contract call, and which bridge contract
 * (destination for claim and retry, source for release) each call is built against.
 */
import {
  ContractFunctionRevertedError,
  ContractFunctionZeroDataError,
  encodeAbiParameters,
  type Hash,
  type WalletClient,
} from 'viem';
import { vi } from 'vitest';

import { ALICE, BOB, L1_CHAIN_ID, L2_CHAIN_ID, MOCK_BRIDGE_TX_1, MOCK_MESSAGE_L1_L2 } from '$mocks';

const readContract = vi.fn();
const simulateContract = vi.fn();
const writeContract = vi.fn();
const getPublicClient = vi.fn();
const recallRead = vi.fn();
const pausedRead = vi.fn();
const { publicEnv } = vi.hoisted(() => ({ publicEnv: {} as Record<string, string | undefined> }));
vi.mock('$env/dynamic/public', () => ({ env: publicEnv }));
vi.mock('@wagmi/core', () => ({
  readContract: (config: unknown, args: { functionName: string }) => {
    if (args.functionName === 'paused') return pausedRead(config, args);
    return readContract(config, args);
  },
  simulateContract: (...args: unknown[]) => simulateContract(...args),
  writeContract: (...args: unknown[]) => writeContract(...args),
  getPublicClient: (...args: unknown[]) => getPublicClient(...args),
}));
vi.mock('$libs/wagmi', () => ({ config: {} }));
vi.mock('$bridgeConfig');
vi.mock('$libs/util/checkForPausedContracts', () => ({ isBridgePaused: vi.fn().mockResolvedValue(false) }));
vi.mock('$libs/util/isSmartContract', () => ({ isSmartContract: vi.fn().mockResolvedValue(false) }));

/** The contract handles processMessage builds; recorded so the test can see which address each call went to */
const built: { address: string }[] = [];
const estimateProcessMessage = vi.fn();
const estimateRetryMessage = vi.fn();
const estimateRecallMessage = vi.fn();
vi.mock('viem', async (importOriginal) => ({
  ...(await importOriginal<typeof import('viem')>()),
  getContract: (options: { address: string; abi: unknown }) => {
    built.push({ address: options.address });
    return {
      address: options.address,
      abi: options.abi,
      estimateGas: {
        processMessage: estimateProcessMessage,
        retryMessage: estimateRetryMessage,
        recallMessage: estimateRecallMessage,
      },
    };
  },
}));

const getConnectedWallet = vi.fn();
vi.mock('$libs/util/getConnectedWallet', () => ({
  getConnectedWallet: (...args: unknown[]) => getConnectedWallet(...args),
}));

import { routingContractsMap } from '$bridgeConfig';
import {
  MessageStatusError,
  ProcessMessageError,
  RecallDisabledError,
  RecallStatusUnknownError,
  WrongChainError,
  WrongOwnerError,
} from '$libs/error';

import { ERC20Bridge } from './ERC20Bridge';
import { type BridgeTransaction, MessageStatus } from './types';

const TX_HASH = '0x00000000000000000000000000000000000000000000000000000000000000aa' as Hash;
const PROOF = '0xp' as Hash;
const RECALL_PROOF = '0xr' as Hash;

const prover = {
  getEncodedSignalProof: vi.fn().mockResolvedValue(PROOF),
  getEncodedSignalProofForRecall: vi.fn().mockResolvedValue(RECALL_PROOF),
};

// The routing map mock knows the 1 <-> 2 pair; the shared message fixture points at chain 21
const srcChainId = L1_CHAIN_ID;
const destChainId = L2_CHAIN_ID;
const MESSAGE = { ...MOCK_MESSAGE_L1_L2, srcChainId: BigInt(srcChainId), destChainId: BigInt(destChainId) };
const destBridge = routingContractsMap[destChainId][srcChainId].bridgeAddress;
const srcBridge = routingContractsMap[srcChainId][destChainId].bridgeAddress;

const walletOn = (chainId: number, address = ALICE) =>
  ({
    account: { address },
    chain: { id: chainId },
    getChainId: vi.fn().mockResolvedValue(chainId),
  }) as unknown as WalletClient;

const bridgeTx = (overrides: Partial<BridgeTransaction> = {}): BridgeTransaction =>
  ({
    ...MOCK_BRIDGE_TX_1,
    srcChainId: BigInt(srcChainId),
    destChainId: BigInt(destChainId),
    message: { ...MESSAGE },
    ...overrides,
  }) as BridgeTransaction;

beforeEach(() => {
  vi.clearAllMocks();
  delete publicEnv.PUBLIC_BRIDGE_RECALL_ENABLED;
  recallRead.mockReset().mockResolvedValue(true);
  pausedRead.mockReset().mockResolvedValue(false);
  built.length = 0;
  simulateContract.mockResolvedValue({ request: { simulated: true } });
  writeContract.mockResolvedValue(TX_HASH);
  estimateProcessMessage.mockResolvedValue(100_000n);
  estimateRetryMessage.mockResolvedValue(100_000n);
  estimateRecallMessage.mockResolvedValue(100_000n);
  getPublicClient.mockImplementation((config, args) => ({
    estimateContractGas: vi.fn().mockResolvedValue(90_000n),
    request: async () => {
      const enabled = await recallRead(config, args);
      return typeof enabled === 'boolean' ? encodeAbiParameters([{ type: 'bool' }], [enabled]) : enabled;
    },
  }));
  getConnectedWallet.mockImplementation(async () => walletOn(destChainId));
});

describe('Bridge recall compatibility', () => {
  const release = () =>
    new ERC20Bridge(prover as never).processMessage({ bridgeTx: bridgeTx(), wallet: walletOn(srcChainId) });
  const retry = () =>
    new ERC20Bridge(prover as never).processMessage({
      bridgeTx: bridgeTx(),
      wallet: walletOn(destChainId),
      lastAttempt: true,
    });

  it.each([undefined, 'true'])('blocks a disabled source recall regardless of the operator flag (%s)', async (flag) => {
    publicEnv.PUBLIC_BRIDGE_RECALL_ENABLED = flag;
    readContract.mockResolvedValue(MessageStatus.FAILED);
    recallRead.mockResolvedValue(false);
    await expect(release()).rejects.toThrow(/recall/i);
    expect(prover.getEncodedSignalProofForRecall).not.toHaveBeenCalled();
    expect(estimateRecallMessage).not.toHaveBeenCalled();
    expect(writeContract).not.toHaveBeenCalled();
  });

  it('ordinary retries do not depend on recall capability reads', async () => {
    readContract.mockResolvedValue(MessageStatus.RETRIABLE);
    recallRead.mockImplementation(() => new Promise(() => {}));
    await expect(
      new ERC20Bridge(prover as never).processMessage({ bridgeTx: bridgeTx(), wallet: walletOn(destChainId) }),
    ).resolves.toBe(TX_HASH);
    expect(recallRead).not.toHaveBeenCalled();
    expect(estimateRetryMessage).toHaveBeenCalledWith([expect.anything(), false], expect.anything());
  });

  it.each([srcChainId, destChainId])('rejects a final retry if chain %s disables recalls', async (disabledChain) => {
    readContract.mockResolvedValue(MessageStatus.RETRIABLE);
    recallRead.mockImplementation(async (_config, { chainId }) => chainId !== disabledChain);
    await expect(retry()).rejects.toBeInstanceOf(RecallDisabledError);
    expect(estimateRetryMessage).not.toHaveBeenCalled();
    expect(writeContract).not.toHaveBeenCalled();
  });

  it.each([srcChainId, destChainId])(
    'rejects a final retry after one failed capability read on chain %s',
    async (failedChain) => {
      readContract.mockResolvedValue(MessageStatus.RETRIABLE);
      recallRead.mockImplementation(async (_config, { chainId }) => {
        if (chainId === failedChain) throw new Error('RPC timeout');
        return true;
      });
      await expect(retry()).rejects.toBeInstanceOf(RecallStatusUnknownError);
      expect(estimateRetryMessage).not.toHaveBeenCalled();
      expect(writeContract).not.toHaveBeenCalled();
    },
  );

  it('can release when only the destination disables recalls', async () => {
    readContract.mockResolvedValue(MessageStatus.FAILED);
    recallRead.mockImplementation(async (_config, { chainId }) => chainId === srcChainId);
    await expect(release()).resolves.toBe(TX_HASH);
  });

  it.each(['false'])(
    'the operator flag blocks release and final retries but allows an explicit ordinary retry (%s)',
    async (flag) => {
      publicEnv.PUBLIC_BRIDGE_RECALL_ENABLED = flag;
      readContract.mockResolvedValue(MessageStatus.FAILED);
      await expect(release()).rejects.toThrow(/recall/i);
      expect(writeContract).not.toHaveBeenCalled();
      readContract.mockResolvedValue(MessageStatus.RETRIABLE);
      await expect(retry()).rejects.toBeInstanceOf(RecallDisabledError);
      expect(writeContract).not.toHaveBeenCalled();
      await expect(
        new ERC20Bridge(prover as never).processMessage({ bridgeTx: bridgeTx(), wallet: walletOn(destChainId) }),
      ).resolves.toBe(TX_HASH);
      expect(estimateRetryMessage).toHaveBeenCalledWith([expect.anything(), false], expect.anything());
    },
  );

  it('preserves legacy recalls after verifying a live bridge with an empty getter result', async () => {
    readContract.mockResolvedValue(MessageStatus.FAILED);
    recallRead.mockResolvedValue('0x');
    await expect(release()).resolves.toBe(TX_HASH);
    readContract.mockResolvedValue(MessageStatus.RETRIABLE);
    await retry();
    expect(estimateRetryMessage).toHaveBeenCalledWith([expect.anything(), true], expect.anything());
  });

  it.each([
    new Error('RPC timeout'),
    new ContractFunctionRevertedError({ abi: [], functionName: 'recallEnabled', data: '0x12345678' }),
    new ContractFunctionRevertedError({ abi: [], functionName: 'recallEnabled', message: 'unauthorized' }),
  ])('never treats an unrelated read failure as a legacy bridge (%s)', async (error) => {
    readContract.mockResolvedValue(MessageStatus.FAILED);
    recallRead.mockRejectedValue(error);
    await expect(release()).rejects.toThrow(/recall/i);
    expect(writeContract).not.toHaveBeenCalled();
    readContract.mockResolvedValue(MessageStatus.RETRIABLE);
    await expect(retry()).rejects.toBeInstanceOf(RecallStatusUnknownError);
    expect(estimateRetryMessage).not.toHaveBeenCalled();
    expect(writeContract).not.toHaveBeenCalled();
  });

  it('does not classify an empty address as a legacy bridge', async () => {
    readContract.mockResolvedValue(MessageStatus.FAILED);
    recallRead.mockResolvedValue('0x');
    pausedRead.mockRejectedValue(new ContractFunctionZeroDataError({ functionName: 'paused' }));
    await expect(release()).rejects.toThrow(/recall/i);
    expect(writeContract).not.toHaveBeenCalled();
  });

  it('rechecks source capability after a recall simulation', async () => {
    readContract.mockResolvedValue(MessageStatus.FAILED);
    simulateContract.mockImplementationOnce(async () => {
      recallRead.mockResolvedValue(false);
      return { request: { simulated: true } };
    });
    await expect(release()).rejects.toThrow(/recall/i);
    expect(writeContract).not.toHaveBeenCalled();
  });

  it.each(['disabled', 'unknown'])('stops a final retry if recall becomes %s during simulation', async (state) => {
    readContract.mockResolvedValue(MessageStatus.RETRIABLE);
    simulateContract.mockImplementationOnce(async () => {
      if (state === 'disabled') recallRead.mockResolvedValue(false);
      else recallRead.mockRejectedValue(new Error('RPC timeout'));
      return { request: { finalAttempt: true } };
    });
    await expect(retry()).rejects.toBeInstanceOf(state === 'disabled' ? RecallDisabledError : RecallStatusUnknownError);
    expect(simulateContract).toHaveBeenCalledOnce();
    expect(writeContract).not.toHaveBeenCalled();
  });
});

describe('Bridge.processMessage preconditions', () => {
  it('refuses a message the caller neither sent nor owns when only the owner may process it', async () => {
    readContract.mockResolvedValue(MessageStatus.NEW);
    const wallet = walletOn(destChainId, BOB); // neither srcOwner nor destOwner

    await expect(
      new ERC20Bridge(prover as never).processMessage({ bridgeTx: bridgeTx(), wallet }),
    ).rejects.toBeInstanceOf(WrongOwnerError);
    expect(writeContract).not.toHaveBeenCalled();
  });

  it('refuses a message that has already been processed', async () => {
    readContract.mockResolvedValue(MessageStatus.DONE);

    await expect(
      new ERC20Bridge(prover as never).processMessage({ bridgeTx: bridgeTx(), wallet: walletOn(destChainId) }),
    ).rejects.toBeInstanceOf(MessageStatusError);
    expect(writeContract).not.toHaveBeenCalled();
  });

  it('refuses to claim from a wallet on the wrong chain', async () => {
    readContract.mockResolvedValue(MessageStatus.NEW);

    await expect(
      new ERC20Bridge(prover as never).processMessage({ bridgeTx: bridgeTx(), wallet: walletOn(srcChainId) }),
    ).rejects.toBeInstanceOf(WrongChainError);
    expect(writeContract).not.toHaveBeenCalled();
  });

  it('refuses to release from a wallet that is not on the source chain', async () => {
    readContract.mockResolvedValue(MessageStatus.FAILED);

    await expect(
      new ERC20Bridge(prover as never).processMessage({ bridgeTx: bridgeTx(), wallet: walletOn(destChainId) }),
    ).rejects.toBeInstanceOf(WrongChainError);
    expect(writeContract).not.toHaveBeenCalled();
  });
});

describe('Bridge.processMessage routes each status to its contract call', () => {
  it('claims a NEW message on the destination bridge with the proof', async () => {
    readContract.mockResolvedValue(MessageStatus.NEW);

    const hash = await new ERC20Bridge(prover as never).processMessage({
      bridgeTx: bridgeTx(),
      wallet: walletOn(destChainId),
    });

    expect(hash).toBe(TX_HASH);
    expect(prover.getEncodedSignalProof).toHaveBeenCalledOnce();
    expect(simulateContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        address: destBridge,
        functionName: 'processMessage',
        args: [expect.anything(), PROOF],
      }),
    );
    expect(writeContract).toHaveBeenCalledWith(expect.anything(), { simulated: true });
  });

  it('retries a RETRIABLE message on the destination bridge, marking the last attempt when asked', async () => {
    readContract.mockResolvedValue(MessageStatus.RETRIABLE);

    await new ERC20Bridge(prover as never).processMessage({
      bridgeTx: bridgeTx(),
      wallet: walletOn(destChainId),
      lastAttempt: true,
    });

    expect(prover.getEncodedSignalProof).not.toHaveBeenCalled();
    expect(simulateContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ address: destBridge, functionName: 'retryMessage', args: [expect.anything(), true] }),
    );
  });

  it('refuses to claim a NEW message with no source height, which the proof needs', async () => {
    readContract.mockResolvedValue(MessageStatus.NEW);

    await expect(
      new ERC20Bridge(prover as never).processMessage({
        bridgeTx: bridgeTx({ blockNumber: undefined, receipt: undefined }),
        wallet: walletOn(destChainId),
      }),
    ).rejects.toBeInstanceOf(ProcessMessageError);
    expect(prover.getEncodedSignalProof).not.toHaveBeenCalled();
  });

  it('retries and releases without a source height, which neither path proves against', async () => {
    // retryMessage sends no proof, and the recall proof is built against the destination chain, so
    // requiring a source height ahead of the dispatch rejected work that would have succeeded - on
    // a button the transaction list had already offered
    readContract.mockResolvedValue(MessageStatus.RETRIABLE);
    await new ERC20Bridge(prover as never).processMessage({
      bridgeTx: bridgeTx({ blockNumber: undefined, receipt: undefined }),
      wallet: walletOn(destChainId),
    });
    expect(simulateContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ functionName: 'retryMessage' }),
    );

    readContract.mockResolvedValue(MessageStatus.FAILED);
    await new ERC20Bridge(prover as never).processMessage({
      bridgeTx: bridgeTx({ blockNumber: undefined, receipt: undefined }),
      wallet: walletOn(srcChainId),
    });
    expect(simulateContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ functionName: 'recallMessage' }),
    );
  });

  it('releases a FAILED message on the SOURCE bridge with the recall proof', async () => {
    // recallMessage lives on the chain the funds left from; the claim contract is the wrong one
    readContract.mockResolvedValue(MessageStatus.FAILED);

    await new ERC20Bridge(prover as never).processMessage({ bridgeTx: bridgeTx(), wallet: walletOn(srcChainId) });

    expect(prover.getEncodedSignalProofForRecall).toHaveBeenCalledOnce();
    expect(simulateContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        address: srcBridge,
        functionName: 'recallMessage',
        args: [expect.anything(), RECALL_PROOF],
      }),
    );
    expect(srcBridge).not.toBe(destBridge);
  });

  it('skips the status read and claims directly when told to', async () => {
    await new ERC20Bridge(prover as never).processMessage(
      { bridgeTx: bridgeTx(), wallet: walletOn(destChainId) },
      false,
      true,
    );

    expect(readContract).not.toHaveBeenCalled();
    expect(simulateContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ address: destBridge, functionName: 'processMessage' }),
    );
  });

  it('writes without simulating when forced', async () => {
    readContract.mockResolvedValue(MessageStatus.NEW);

    await new ERC20Bridge(prover as never).processMessage(
      { bridgeTx: bridgeTx(), wallet: walletOn(destChainId) },
      true,
    );

    expect(simulateContract).not.toHaveBeenCalled();
    expect(writeContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ address: destBridge, functionName: 'processMessage' }),
    );
  });

  it('refuses a status it has no action for', async () => {
    readContract.mockResolvedValue(MessageStatus.RECALLED);

    await expect(
      new ERC20Bridge(prover as never).processMessage({ bridgeTx: bridgeTx(), wallet: walletOn(destChainId) }),
    ).rejects.toThrow('Message status not supported');
  });
});
