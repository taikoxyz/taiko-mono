/**
 * The claim / retry / release paths shared by every bridge. These are the calls that move
 * funds on the destination or source chain after a send, and nothing exercised them: the
 * preconditions, which status routes to which contract call, and which bridge contract
 * (destination for claim and retry, source for release) each call is built against.
 */
import type { Hash, WalletClient } from 'viem';
import { vi } from 'vitest';

import { ALICE, BOB, L1_CHAIN_ID, L2_CHAIN_ID, MOCK_BRIDGE_TX_1, MOCK_MESSAGE_L1_L2 } from '$mocks';

const readContract = vi.fn();
const simulateContract = vi.fn();
const writeContract = vi.fn();
const getPublicClient = vi.fn();
vi.mock('@wagmi/core', () => ({
  readContract: (...args: unknown[]) => readContract(...args),
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
import { MessageStatusError, WrongChainError, WrongOwnerError } from '$libs/error';

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
  built.length = 0;
  simulateContract.mockResolvedValue({ request: { simulated: true } });
  writeContract.mockResolvedValue(TX_HASH);
  estimateProcessMessage.mockResolvedValue(100_000n);
  estimateRetryMessage.mockResolvedValue(100_000n);
  estimateRecallMessage.mockResolvedValue(100_000n);
  getPublicClient.mockReturnValue({ estimateContractGas: vi.fn().mockResolvedValue(90_000n) });
  getConnectedWallet.mockImplementation(async () => walletOn(destChainId));
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
