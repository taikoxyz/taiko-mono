import { type GetBalanceReturnType } from '@wagmi/core';
import { formatEther } from 'viem';

import { truncateString } from '../../lib/util/truncateString';

export function renderBalance(balance?: GetBalanceReturnType) {
  if (!balance) return '0.00';
  // if (typeof balance === 'bigint') return balance.toString();
  const maxlength = Number(balance.formatted) < 0.000001 ? balance.decimals : 6;
  return `${truncateString(balance.formatted, maxlength, '')} ${truncateString(balance.symbol, 7)}`;
}

export function renderEthBalance(balance: bigint, maxlength = 8): string {
  return `${truncateString(formatEther(balance).toString(), maxlength, '')} ETH`;
}

export const refreshUserBalance = async () => {};
