import type { BigNumber } from 'ethers';

export type Prover = {
  currentCapacity: number;
  address: string;
  stakedAmount: BigNumber;
  amountStaked: BigNumber; // stupid hack
};

export type ProversResp = {
  provers: Array<Prover>;
};
