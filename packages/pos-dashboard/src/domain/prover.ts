export type Prover = {
  currentCapacity: number;
  address: string;
  amountStaked: BigNumber;
};

export type ProversResp = {
  provers: Array<Prover>;
};
