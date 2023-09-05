import { type FetchBalanceResult, getAccount, getPublicClient } from '@wagmi/core';
import { formatEther } from 'viem';

import { truncateString } from '$libs/util/truncateString';
import { ethBalance } from '$stores/balance';

export function renderBalance(balance: Maybe<FetchBalanceResult>) {
  if (!balance) return '0.00';

  const maxlength = Number(balance.formatted) < 0.000001 ? balance.decimals : 6;
  return `${truncateString(balance.formatted, maxlength, '')} ${balance.symbol}`;
}

export function renderEthBalance(balance: bigint, maxlength = 8): string {
  return `${truncateString(formatEther(balance).toString(), maxlength, '')} ETH`;
}

export const refreshUserBalance = async () => {
  const account = getAccount();
  let balance = BigInt(0);
  if (account?.address) {
    balance = await getPublicClient().getBalance({ address: account.address });
  }
  ethBalance.set(balance);
};
