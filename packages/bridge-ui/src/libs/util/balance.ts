import { getAccount, getBalance, type GetBalanceReturnType } from '@wagmi/core';
import { formatEther } from 'viem';

import { truncateString } from '$libs/util/truncateString';
import { config } from '$libs/wagmi';
import { ethBalance } from '$stores/balance';

export function renderBalance(balance: Maybe<GetBalanceReturnType>) {
  if (!balance) return '0.00';
  // if (typeof balance === 'bigint') return balance.toString();
  const maxlength = Number(balance.formatted) < 0.000001 ? balance.decimals : 6;
  return `${truncateString(balance.formatted, maxlength, '')} ${truncateString(balance.symbol, 7)}`;
}

export function renderEthBalance(balance: bigint, maxlength = 8): string {
  return `${truncateString(formatEther(balance).toString(), maxlength, '')} ETH`;
}

export const refreshUserBalance = async () => {
  const account = getAccount(config);
  let balance = BigInt(0);
  if (account?.address) {
    balance = (await getBalance(config, { address: account.address })).value;
  }
  ethBalance.set(balance);
};
