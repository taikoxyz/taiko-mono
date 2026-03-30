import { useState, useCallback, useEffect } from 'react';
import { Address } from 'viem';

const STORAGE_KEY_PREFIX = 'surge_l2_spending_';
const MAX_L2_SPENDING_USD = 1;

function getStorageKey(wallet: string): string {
  return `${STORAGE_KEY_PREFIX}${wallet.toLowerCase()}`;
}

function readSpending(wallet: string): number {
  try {
    const val = localStorage.getItem(getStorageKey(wallet));
    return val ? Number(val) : 0;
  } catch {
    return 0;
  }
}

function writeSpending(wallet: string, total: number): void {
  try {
    localStorage.setItem(getStorageKey(wallet), String(total));
  } catch {
    // localStorage full or unavailable
  }
}

export function useSpendingLimit(wallet: Address | null) {
  const [totalSpent, setTotalSpent] = useState(0);

  useEffect(() => {
    if (wallet) {
      setTotalSpent(readSpending(wallet));
    } else {
      setTotalSpent(0);
    }
  }, [wallet]);

  const remaining = Math.max(0, MAX_L2_SPENDING_USD - totalSpent);
  const hasExceededL2Limit = totalSpent >= MAX_L2_SPENDING_USD;

  const recordSpending = useCallback(
    (amountUsd: number) => {
      if (!wallet) return;
      const updated = readSpending(wallet) + amountUsd;
      writeSpending(wallet, updated);
      setTotalSpent(updated);
    },
    [wallet],
  );

  const wouldExceed = useCallback(
    (amountUsd: number) => totalSpent + amountUsd > MAX_L2_SPENDING_USD,
    [totalSpent],
  );

  return { totalSpent, remaining, hasExceededL2Limit, recordSpending, wouldExceed, maxUsd: MAX_L2_SPENDING_USD };
}
