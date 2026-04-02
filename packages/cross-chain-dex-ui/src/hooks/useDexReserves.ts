import { useState, useEffect, useCallback } from 'react';
import { DexReserves } from '../types';
import { SimpleDEXABI } from '../lib/contracts';
import { SIMPLE_DEX } from '../lib/constants';
import { l2PublicClient } from '../lib/config';
import { usePageVisible } from './usePageVisible';

export function useDexReserves() {
  const pageVisible = usePageVisible();
  const [reserves, setReserves] = useState<DexReserves>({
    ethReserve: 0n,
    tokenReserve: 0n,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchReserves = useCallback(async () => {
    if (!SIMPLE_DEX || SIMPLE_DEX === '0x0000000000000000000000000000000000000000') {
      setIsLoading(false);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      const result = await l2PublicClient.readContract({
        address: SIMPLE_DEX,
        abi: SimpleDEXABI,
        functionName: 'getReserves',
      });

      setReserves({
        ethReserve: result[0],
        tokenReserve: result[1],
      });
    } catch (err) {
      console.error('Failed to fetch DEX reserves:', err);
      setError(err instanceof Error ? err : new Error('Failed to fetch reserves'));
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!pageVisible) return;
    fetchReserves();

    const interval = setInterval(fetchReserves, 10000);
    return () => clearInterval(interval);
  }, [fetchReserves, pageVisible]);

  return {
    ...reserves,
    isLoading,
    error,
    refetch: fetchReserves,
  };
}
