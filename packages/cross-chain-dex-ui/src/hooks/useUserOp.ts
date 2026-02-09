import { useState, useCallback } from 'react';
import { Address, Hex } from 'viem';
import { useWalletClient } from 'wagmi';
import toast from 'react-hot-toast';
import { SwapDirection } from '../types';
import {
  buildSwapUserOps,
  computeUserOpsDigest,
  sendUserOpToBuilder,
  calculateMinOutput,
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

        if (result.success) {
          toast.success('Swap submitted successfully!', { id: 'swap' });
          return true;
        } else {
          toast.error(result.error || 'Failed to submit swap', { id: 'swap' });
          setError(new Error(result.error || 'Failed to submit swap'));
          return false;
        }
      } catch (err) {
        console.error('Swap failed:', err);
        const errorMessage = err instanceof Error ? err.message : 'Swap failed';
        toast.error(errorMessage, { id: 'swap' });
        setError(err instanceof Error ? err : new Error(errorMessage));
        return false;
      } finally {
        setIsPending(false);
      }
    },
    [walletClient]
  );

  return {
    executeSwap,
    isPending,
    error,
  };
}
