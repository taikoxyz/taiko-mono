import type { BigNumber } from 'ethers';

type Staker = {
  exitRequestedAt: BigNumber;
  exitAmount: BigNumber;
  maxCapacity: BigNumber;
  proverId: number;
};

export { Staker };
