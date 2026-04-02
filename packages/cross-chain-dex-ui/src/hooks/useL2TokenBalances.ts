import { useState, useEffect, useCallback } from 'react';
import { Address, formatEther, formatUnits } from 'viem';
import { ERC20ABI } from '../lib/contracts';
import { USDC_TOKEN } from '../lib/constants';
import { l2PublicClient } from '../lib/config';
import { usePageVisible } from './usePageVisible';

interface TokenBalances {
  ethBalance: bigint;
  usdcBalance: bigint;
  ethFormatted: string;
  usdcFormatted: string;
  isLoading: boolean;
  error: Error | null;
  refetch: () => void;
}

export function useL2TokenBalances(smartWallet: Address | null): TokenBalances {
  const pageVisible = usePageVisible();
  const [ethBalance, setEthBalance] = useState<bigint>(0n);
  const [usdcBalance, setUsdcBalance] = useState<bigint>(0n);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchBalances = useCallback(async () => {
    if (!smartWallet) {
      setEthBalance(0n);
      setUsdcBalance(0n);
      setIsLoading(false);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      // Fetch native balance on L2
      const ethBal = await l2PublicClient.getBalance({ address: smartWallet });
      setEthBalance(ethBal);

      // Fetch USDC balance on L2 (may not exist if token isn't bridged)
      if (USDC_TOKEN.address && USDC_TOKEN.address !== '0x0000000000000000000000000000000000000000') {
        try {
          const usdcBal = await l2PublicClient.readContract({
            address: USDC_TOKEN.address,
            abi: ERC20ABI,
            functionName: 'balanceOf',
            args: [smartWallet],
          });
          setUsdcBalance(usdcBal);
        } catch {
          // Token contract may not exist on L2
          setUsdcBalance(0n);
        }
      }
    } catch (err) {
      console.error('Failed to fetch L2 balances:', err);
      setError(err instanceof Error ? err : new Error('Failed to fetch L2 balances'));
    } finally {
      setIsLoading(false);
    }
  }, [smartWallet]);

  useEffect(() => {
    if (!pageVisible) return;
    fetchBalances();

    const interval = setInterval(fetchBalances, 5000);
    return () => clearInterval(interval);
  }, [fetchBalances, pageVisible]);

  return {
    ethBalance,
    usdcBalance,
    ethFormatted: formatEther(ethBalance),
    usdcFormatted: formatUnits(usdcBalance, USDC_TOKEN.decimals),
    isLoading,
    error,
    refetch: fetchBalances,
  };
}
