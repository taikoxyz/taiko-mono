import { useState, useCallback, useRef, useEffect } from 'react';
import { Address, Hex } from 'viem';
import { useWalletClient } from 'wagmi';
import toast from 'react-hot-toast';
import { SwapDirection } from '../types';
import {
  buildSwapUserOps,
  computeUserOpsDigest,
  sendUserOpToBuilder,
  calculateMinOutput,
  queryUserOpStatus,
} from '../lib/userOp';
import { DEFAULT_SLIPPAGE } from '../lib/constants';

interface UseUserOpReturn {
  executeSwap: (params: ExecuteSwapParams) => Promise<boolean>;
  isPending: boolean;
  error: Error | null;
}

interface ExecuteSwapParams {
  direction: SwapDirection;
  amountIn: bigint;
  expectedAmountOut: bigint;
  smartWallet: Address;
  slippage?: number;
}

export function useUserOp(): UseUserOpReturn {
  const { data: walletClient } = useWalletClient();
  const [isPending, setIsPending] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const pollIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Clean up polling on unmount
  useEffect(() => {
    return () => {
      if (pollIntervalRef.current) {
        clearInterval(pollIntervalRef.current);
      }
    };
  }, []);

  const pollStatus = useCallback((userOpId: number): Promise<boolean> => {
    return new Promise((resolve) => {
      toast.loading('Waiting for execution...', { id: 'swap' });

      pollIntervalRef.current = setInterval(async () => {
        const status = await queryUserOpStatus(userOpId);
        if (!status) return;

        if (status.status === 'Processing') {
          toast.loading(`Processing (tx: ${status.tx_hash.slice(0, 10)}...)`, { id: 'swap' });
        } else if (status.status === 'Executed') {
          if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
          pollIntervalRef.current = null;
          toast.success('Swap executed successfully!', { id: 'swap' });
          setIsPending(false);
          resolve(true);
        } else if (status.status === 'Rejected') {
          if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
          pollIntervalRef.current = null;
          toast.error(`Swap rejected: ${status.reason}`, { id: 'swap' });
          setError(new Error(status.reason));
          setIsPending(false);
          resolve(false);
        }
        // Pending: keep polling
      }, 1000);
    });
  }, []);

  const executeSwap = useCallback(
    async ({
      direction,
      amountIn,
      expectedAmountOut,
      smartWallet,
      slippage = DEFAULT_SLIPPAGE,
    }: ExecuteSwapParams): Promise<boolean> => {
      if (!walletClient) {
        toast.error('Wallet not connected');
        return false;
      }

      setIsPending(true);
      setError(null);

      try {
        // Calculate minimum output with slippage
        const minAmountOut = calculateMinOutput(expectedAmountOut, slippage);

        // Build UserOp(s)
        const ops = buildSwapUserOps(direction, amountIn, minAmountOut, smartWallet);

        toast.loading('Signing transaction...', { id: 'swap' });

        // Compute digest
        const digest = computeUserOpsDigest(ops);
        console.log('UserOps:', ops);
        console.log('Digest to sign:', digest);
        console.log('Signer address:', walletClient.account.address);

        // Sign the digest using signMessage (standard personal_sign)
        // The contract uses MessageHashUtils.toEthSignedMessageHash to add the Ethereum prefix
        // before recovering the signer address
        const signature = await walletClient.signMessage({
          message: { raw: digest as `0x${string}` },
        });
        console.log('Signature:', signature);

        toast.loading('Sending to builder...', { id: 'swap' });

        // Send to builder RPC
        const result = await sendUserOpToBuilder(smartWallet, ops, signature as Hex);

        if (result.success && result.userOpId !== undefined) {
          // Poll for status
          return await pollStatus(result.userOpId);
        } else if (result.success) {
          // No ID returned, can't poll - just show success
          toast.success('Swap submitted successfully!', { id: 'swap' });
          setIsPending(false);
          return true;
        } else {
          toast.error(result.error || 'Failed to submit swap', { id: 'swap' });
          setError(new Error(result.error || 'Failed to submit swap'));
          setIsPending(false);
          return false;
        }
      } catch (err) {
        console.error('Swap failed:', err);
        const errorMessage = err instanceof Error ? err.message : 'Swap failed';
        toast.error(errorMessage, { id: 'swap' });
        setError(err instanceof Error ? err : new Error(errorMessage));
        setIsPending(false);
        return false;
      }
    },
    [walletClient, pollStatus]
  );

  return {
    executeSwap,
    isPending,
    error,
  };
}
