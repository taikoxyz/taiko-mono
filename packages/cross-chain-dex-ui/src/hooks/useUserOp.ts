import { useState, useCallback, useRef, useEffect } from 'react';
import { Address, Hex } from 'viem';
import { useWalletClient, useSwitchChain, useConfig } from 'wagmi';
import { getWalletClient } from 'wagmi/actions';
import { SwapDirection, AccountMode } from '../types';
import {
  getAmbireNonce,
  computeExecuteHash,
  appendEIP712Mode,
  userOpsToAmbireTransactions,
  buildAmbireExecuteCalldata,
  buildAmbireExecuteTypedData,
} from '../lib/ambireOp';
import {
  buildSwapUserOps,
  buildBridgeUserOps,
  buildBridgeNativeUserOps,
  buildBridgeOutNativeUserOps,
  buildAddLiquidityUserOps,
  buildRemoveLiquidityUserOps,
  buildWithdrawUserOps,
  buildCreateL2SafeOps,
  userOpsToSafeTx,
  sendUserOpToBuilder,
  calculateMinOutput,
  queryTxStatus,
} from '../lib/userOp';
import { getSafeNonce, buildSafeTxTypedData, buildExecTransactionCalldata } from '../lib/safeOp';
import { UserOp } from '../types';
import { CHAIN_ID, L2_CHAIN_ID, DEFAULT_SLIPPAGE } from '../lib/constants';
import { l1PublicClient, l2PublicClient } from '../lib/config';
import { useTxStatus } from '../context/TxStatusContext';

function parseWalletError(err: unknown): string {
  const raw = err instanceof Error ? err.message : 'Operation failed';
  if (raw.includes('rejected') || raw.includes('denied')) return 'Transaction rejected by user';
  // Strip verbose viem details (Request Arguments, Details, Version)
  const detailsMatch = raw.match(/Details:\s*(.+?)(?:\.|$)/);
  if (detailsMatch) return detailsMatch[1].trim();
  // Fallback: take first sentence
  const firstSentence = raw.split(/[.\n]/)[0].trim();
  return firstSentence.length > 120 ? firstSentence.slice(0, 120) + '...' : firstSentence;
}

interface UseUserOpReturn {
  executeSwap: (params: ExecuteSwapParams) => Promise<boolean>;
  executeBridge: (params: ExecuteBridgeParams) => Promise<boolean>;
  executeBridgeNative: (params: ExecuteBridgeNativeParams) => Promise<boolean>;
  executeBridgeOutNative: (params: ExecuteBridgeNativeParams) => Promise<boolean>;
  executeAddLiquidity: (params: ExecuteAddLiquidityParams) => Promise<boolean>;
  executeRemoveLiquidity: (params: { smartWallet: Address }) => Promise<boolean>;
  executeWithdraw: (params: { owner: Address; smartWallet: Address; ethBalance: bigint; usdcBalance: bigint }) => Promise<boolean>;
  executeCreateL2Wallet: (params: { owner: Address; smartWallet: Address }) => Promise<boolean>;
  isPending: boolean;
  error: Error | null;
}

interface ExecuteBridgeNativeParams {
  amount: bigint;
  recipient: Address;
  smartWallet: Address;
}

interface ExecuteSwapParams {
  direction: SwapDirection;
  amountIn: bigint;
  expectedAmountOut: bigint;
  smartWallet: Address;
  slippage?: number;
}

interface ExecuteBridgeParams {
  amount: bigint;
  recipient: Address;
  smartWallet: Address;
}

interface ExecuteAddLiquidityParams {
  ethAmount: bigint;
  tokenAmount: bigint;
  smartWallet: Address;
}

export function useUserOp(accountMode: AccountMode = 'safe'): UseUserOpReturn {
  const { data: walletClient } = useWalletClient();
  const { switchChainAsync } = useSwitchChain();
  const wagmiConfig = useConfig();
  const { setTxStatus } = useTxStatus();
  const [isPending, setIsPending] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const pollIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const txHashRef = useRef<string | undefined>(undefined);

  useEffect(() => {
    return () => {
      if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    };
  }, []);

  const pollStatus = useCallback((query: { userOpId: number } | { txHash: string }): Promise<boolean> => {
    return new Promise((resolve) => {
      setTxStatus({ phase: 'sequencing' });

      // Phase ordering: sequencing(0) < proving(1) < proposing(2) < complete(3)
      // proving comes before proposing because the ZK proof is generated before L1 submission
      const phaseOrder: Record<string, number> = {
        sequencing: 0, proving: 1, proposing: 2, complete: 3, rejected: 3,
      };
      let highestPhase = 0;
      let hasSeenProving = false;
      let pollCount = 0;
      const MAX_POLLS = 60; // 1 minute at 1s intervals

      pollIntervalRef.current = setInterval(async () => {
        pollCount++;
        if (pollCount > MAX_POLLS) {
          if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
          pollIntervalRef.current = null;
          setTxStatus({ phase: 'rejected', errorMessage: 'Transaction timed out' });
          setError(new Error('Transaction timed out'));
          setIsPending(false);
          resolve(false);
          return;
        }

        const status = await queryTxStatus(query);
        if (!status) return;

        if (status.status === 'Pending') {
          if (highestPhase <= phaseOrder.sequencing) {
            setTxStatus({ phase: 'sequencing' });
          }
        } else if (status.status === 'ProvingBlock') {
          hasSeenProving = true;
          if (phaseOrder.proving > highestPhase) {
            highestPhase = phaseOrder.proving;
            setTxStatus({ phase: 'proving' });
          }
        } else if (status.status === 'Processing') {
          txHashRef.current = status.tx_hash;
          // Only show "proposing" after proving has been seen
          // Before proving, Processing means "sequencing"
          if (hasSeenProving && phaseOrder.proposing > highestPhase) {
            highestPhase = phaseOrder.proposing;
            setTxStatus({ phase: 'proposing' });
          } else if (!hasSeenProving && highestPhase <= phaseOrder.sequencing) {
            setTxStatus({ phase: 'sequencing' });
          }
        } else if (status.status === 'Executed') {
          if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
          pollIntervalRef.current = null;
          setTxStatus({ phase: 'complete', txHash: txHashRef.current });
          setIsPending(false);
          resolve(true);
        } else if (status.status === 'Rejected') {
          if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
          pollIntervalRef.current = null;
          setTxStatus({ phase: 'rejected', errorMessage: status.reason });
          setError(new Error(status.reason));
          setIsPending(false);
          resolve(false);
        }
      }, 1000);
    });
  }, [setTxStatus]);

  const executeGenericOps = useCallback(
    async (ops: UserOp[], smartWallet: Address, chainId?: number): Promise<boolean> => {
      if (!walletClient) {
        setTxStatus({ phase: 'rejected', errorMessage: 'Wallet not connected' });
        return false;
      }

      setIsPending(true);
      setError(null);
      txHashRef.current = undefined;

      try {
        setTxStatus({ phase: 'signing' });

        const targetChainId = chainId ?? CHAIN_ID;
        const publicClient = targetChainId === L2_CHAIN_ID ? l2PublicClient : l1PublicClient;

        // Switch chain and get a fresh wallet client (the hook value is stale
        // inside this callback until React re-renders).
        let activeClient = walletClient;
        if (targetChainId !== walletClient.chain?.id) {
          await switchChainAsync({ chainId: targetChainId });
          activeClient = await getWalletClient(wagmiConfig, { chainId: targetChainId });
        }

        let calldata: Hex;

        if (accountMode === 'ambire' && targetChainId === L2_CHAIN_ID) {
          // Ambire mode on L2: no 7702 delegation, send as direct EOA transaction
          if (ops.length > 1) throw new Error('Ambire L2 mode only supports single-op transactions');
          const op = ops[0];
          const txHash = await activeClient.sendTransaction({
            to: op.target,
            value: op.value,
            data: op.data,
            chain: activeClient.chain,
            account: activeClient.account,
          });
          setTxStatus({ phase: 'sequencing' });
          await l2PublicClient.waitForTransactionReceipt({ hash: txHash });
          return await pollStatus({ txHash });
        } else if (accountMode === 'ambire') {
          // AmbireAccount path on L1: personal_sign + execute()
          const txns = userOpsToAmbireTransactions(ops);
          const nonce = await getAmbireNonce(publicClient, smartWallet);
          const executeHash = computeExecuteHash(smartWallet, targetChainId, nonce, txns);

          // Sign using AmbireExecuteAccountOp EIP-712 typed data (mode 0x00 = EIP712 direct)
          const typedData = buildAmbireExecuteTypedData(smartWallet, targetChainId, nonce, txns, executeHash);
          const rawSignature = await activeClient.signTypedData(typedData);

          const signature = appendEIP712Mode(rawSignature as Hex);
          calldata = buildAmbireExecuteCalldata(txns, signature);
        } else {
          // Safe path: signTypedData + execTransaction()
          const nonce = await getSafeNonce(publicClient, smartWallet);
          const safeTx = userOpsToSafeTx(ops);
          const typedData = buildSafeTxTypedData(smartWallet, targetChainId, nonce, safeTx);
          const signature = await activeClient.signTypedData(typedData);
          calldata = buildExecTransactionCalldata(safeTx, signature as Hex);
        }

        const result = await sendUserOpToBuilder(smartWallet, calldata, chainId);

        if (result.success && result.userOpId !== undefined) {
          return await pollStatus({ userOpId: result.userOpId });
        } else if (result.success) {
          setTxStatus({ phase: 'complete' });
          setIsPending(false);
          return true;
        } else {
          setTxStatus({ phase: 'rejected', errorMessage: result.error || 'Failed to submit' });
          setError(new Error(result.error || 'Failed to submit'));
          setIsPending(false);
          return false;
        }
      } catch (err) {
        console.error('Operation failed:', err);
        const msg = parseWalletError(err);
        setTxStatus({ phase: 'rejected', errorMessage: msg });
        setError(err instanceof Error ? err : new Error(msg));
        setIsPending(false);
        return false;
      }
    },
    [walletClient, switchChainAsync, wagmiConfig, pollStatus, setTxStatus, accountMode]
  );

  const executeSwap = useCallback(
    async ({
      direction,
      amountIn,
      expectedAmountOut,
      smartWallet,
      slippage = DEFAULT_SLIPPAGE,
    }: ExecuteSwapParams): Promise<boolean> => {
      const minAmountOut = calculateMinOutput(expectedAmountOut, slippage);
      const ops = buildSwapUserOps(direction, amountIn, minAmountOut, smartWallet);
      return executeGenericOps(ops, smartWallet);
    },
    [executeGenericOps]
  );

  const executeBridge = useCallback(
    async ({ amount, recipient, smartWallet }: ExecuteBridgeParams): Promise<boolean> => {
      const ops = buildBridgeUserOps(amount, recipient);
      return executeGenericOps(ops, smartWallet);
    },
    [executeGenericOps]
  );

  const executeBridgeNative = useCallback(
    async ({ amount, recipient, smartWallet }: ExecuteBridgeNativeParams): Promise<boolean> => {
      const ops = buildBridgeNativeUserOps(amount, recipient, smartWallet);
      return executeGenericOps(ops, smartWallet);
    },
    [executeGenericOps]
  );

  const executeBridgeOutNative = useCallback(
    async ({ amount, recipient, smartWallet }: ExecuteBridgeNativeParams): Promise<boolean> => {
      const ops = buildBridgeOutNativeUserOps(amount, recipient, smartWallet);
      return executeGenericOps(ops, smartWallet, L2_CHAIN_ID);
    },
    [executeGenericOps]
  );

  const executeAddLiquidity = useCallback(
    async ({ ethAmount, tokenAmount, smartWallet }: ExecuteAddLiquidityParams): Promise<boolean> => {
      const ops = buildAddLiquidityUserOps(ethAmount, tokenAmount);
      return executeGenericOps(ops, smartWallet);
    },
    [executeGenericOps]
  );

  const executeRemoveLiquidity = useCallback(
    async ({ smartWallet }: { smartWallet: Address }): Promise<boolean> => {
      const ops = buildRemoveLiquidityUserOps();
      return executeGenericOps(ops, smartWallet);
    },
    [executeGenericOps]
  );

  const executeWithdraw = useCallback(
    async ({ owner, smartWallet, ethBalance, usdcBalance }: { owner: Address; smartWallet: Address; ethBalance: bigint; usdcBalance: bigint }): Promise<boolean> => {
      if (!walletClient) return false;

      const ops = buildWithdrawUserOps(owner, ethBalance, usdcBalance);
      if (ops.length === 0) return false;

      setIsPending(true);
      setError(null);
      txHashRef.current = undefined;

      try {
        // Withdraw always targets L1 — ensure wallet is on the right chain.
        // Get a fresh wallet client after switching (hook value is stale).
        let activeClient = walletClient;
        if (CHAIN_ID !== walletClient.chain?.id) {
          await switchChainAsync({ chainId: CHAIN_ID });
          activeClient = await getWalletClient(wagmiConfig, { chainId: CHAIN_ID });
        }

        setTxStatus({ phase: 'signing' });
        let calldata: Hex;

        if (accountMode === 'ambire') {
          const txns = userOpsToAmbireTransactions(ops);
          const nonce = await getAmbireNonce(l1PublicClient, smartWallet);
          const executeHash = computeExecuteHash(smartWallet, CHAIN_ID, nonce, txns);
          const typedData = buildAmbireExecuteTypedData(smartWallet, CHAIN_ID, nonce, txns, executeHash);
          const rawSignature = await activeClient.signTypedData(typedData);
          const signature = appendEIP712Mode(rawSignature as Hex);
          calldata = buildAmbireExecuteCalldata(txns, signature);
        } else {
          const nonce = await getSafeNonce(l1PublicClient, smartWallet);
          const safeTx = userOpsToSafeTx(ops);
          const typedData = buildSafeTxTypedData(smartWallet, CHAIN_ID, nonce, safeTx);
          const signature = await activeClient.signTypedData(typedData);
          calldata = buildExecTransactionCalldata(safeTx, signature as Hex);
        }

        if (accountMode === 'ambire') {
          const result = await sendUserOpToBuilder(smartWallet, calldata);
          if (result.success && result.userOpId !== undefined) {
            return await pollStatus({ userOpId: result.userOpId });
          } else if (result.success) {
            setTxStatus({ phase: 'complete' });
            setIsPending(false);
            return true;
          } else {
            setTxStatus({ phase: 'rejected', errorMessage: result.error || 'Failed to submit' });
            setError(new Error(result.error || 'Failed to submit'));
            setIsPending(false);
            return false;
          }
        } else {
          const txHash = await activeClient.sendTransaction({
            to: smartWallet,
            data: calldata,
            chain: activeClient.chain,
            account: activeClient.account,
          });
          setTxStatus({ phase: 'sequencing' });
          await l1PublicClient.waitForTransactionReceipt({ hash: txHash });
          setTxStatus({ phase: 'complete', txHash });
          setIsPending(false);
          return true;
        }
      } catch (err) {
        console.error('Withdraw failed:', err);
        const msg = parseWalletError(err);
        setTxStatus({ phase: 'rejected', errorMessage: msg });
        setError(err instanceof Error ? err : new Error(msg));
        setIsPending(false);
        return false;
      }
    },
    [walletClient, accountMode, pollStatus, setTxStatus, switchChainAsync, wagmiConfig]
  );

  const executeCreateL2Wallet = useCallback(
    async ({ owner, smartWallet }: { owner: Address; smartWallet: Address }): Promise<boolean> => {
      const ops = buildCreateL2SafeOps(owner, smartWallet);
      return executeGenericOps(ops, smartWallet);
    },
    [executeGenericOps]
  );

  return {
    executeSwap,
    executeBridge,
    executeBridgeNative,
    executeBridgeOutNative,
    executeAddLiquidity,
    executeRemoveLiquidity,
    executeWithdraw,
    executeCreateL2Wallet,
    isPending,
    error,
  };
}
