import { useState, useEffect, useCallback } from 'react';
import { Address } from 'viem';
import { SimpleDEXABI } from '../lib/contracts';
import { SIMPLE_DEX } from '../lib/constants';
import { l2PublicClient } from '../lib/config';

export function useLiquidityPosition(smartWallet: Address | null) {
  const [ethAmount, setEthAmount] = useState(0n);
  const [tokenAmount, setTokenAmount] = useState(0n);

  const fetchPosition = useCallback(async () => {
    if (!smartWallet || !SIMPLE_DEX) {
      setEthAmount(0n);
      setTokenAmount(0n);
      return;
    }

    try {
      const result = await l2PublicClient.readContract({
        address: SIMPLE_DEX,
        abi: SimpleDEXABI,
        functionName: 'getLiquidity',
        args: [smartWallet],
      });

      setEthAmount(result[0]);
      setTokenAmount(result[1]);
    } catch (err) {
      console.error('Failed to fetch liquidity position:', err);
    }
  }, [smartWallet]);

  useEffect(() => {
    fetchPosition();
    const interval = setInterval(fetchPosition, 10000);
    return () => clearInterval(interval);
  }, [fetchPosition]);

  return {
    ethAmount,
    tokenAmount,
    hasPosition: ethAmount > 0n || tokenAmount > 0n,
    refetch: fetchPosition,
  };
}
