import type { FetchBalanceResult } from '@wagmi/core';

import { truncateString } from '$libs/util/truncateString';

export function renderBalance(balance: Maybe<FetchBalanceResult>) {
  if (!balance) return '0.00';

  const maxlength = Number(balance.formatted) < 0.000001 ? balance.decimals : 6;
  return `${truncateString(balance.formatted, maxlength, '')} ${balance.symbol}`;
}
