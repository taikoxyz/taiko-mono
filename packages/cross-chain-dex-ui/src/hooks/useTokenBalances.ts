import { useState, useEffect, useCallback } from 'react';
import { Address, formatEther, formatUnits } from 'viem';
import { ERC20ABI } from '../lib/contracts';
import { USDC_TOKEN } from '../lib/constants';
import { l1PublicClient } from '../lib/config';

interface TokenBalances {
  ethBalance: bigint;
  usdcBalance: bigint;
  ethFormatted: string;
  usdcFormatted: string;
  isLoading: boolean;
  error: Error | null;
  refetch: () => void;
}

export function useTokenBalances(smartWallet: Address | null): TokenBalances {
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

      // Fetch ETH balance
      const ethBal = await l1PublicClient.getBalance({ address: smartWallet });
      setEthBalance(ethBal);

      // Fetch USDC balance
      if (USDC_TOKEN.address && USDC_TOKEN.address !== '0x0000000000000000000000000000000000000000') {
        const usdcBal = await l1PublicClient.readContract({
          address: USDC_TOKEN.address,
          abi: ERC20ABI,
          functionName: 'balanceOf',
          args: [smartWallet],
        });
        setUsdcBalance(usdcBal);
      }
    } catch (err) {
      console.error('Failed to fetch balances:', err);
      setError(err instanceof Error ? err : new Error('Failed to fetch balances'));
    } finally {
      setIsLoading(false);
    }
  }, [smartWallet]);

  useEffect(() => {
    fetchBalances();

    // Poll every 3 seconds
    const interval = setInterval(fetchBalances, 3000);
    return () => clearInterval(interval);
  }, [fetchBalances]);

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
