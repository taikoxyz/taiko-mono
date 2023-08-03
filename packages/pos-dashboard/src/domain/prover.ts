import type { BigNumber } from 'ethers';

export type Prover = {
  currentCapacity: number;
  address: string;
  stakedAmount: BigNumber;
  amountStaked: BigNumber; // stupid hack
  rewardPerGas: number;
};

export type ProversResp = {
  provers: Array<Prover>;
};
