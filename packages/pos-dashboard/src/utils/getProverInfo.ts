import { BigNumber, Contract, ethers } from 'ethers';
import type { Prover } from '../domain/prover';
import type { Staker } from '../domain/staker';
import ProverPool from '../constants/abi/ProverPool';

export const getProverInfo = async (
  provider: ethers.providers.Provider,
  contractAddress: string,
  userAddress: string,
): Promise<{ prover: Prover; staker: Staker; address: string }> => {
  const contract: Contract = new Contract(
    contractAddress,
    ProverPool,
    provider,
  );

  const resp: { prover: Prover; staker: Staker; address: '' } = {
    staker: {
      maxCapacity: BigNumber.from(0),
      exitAmount: BigNumber.from(0),
      exitRequestedAt: BigNumber.from(0),
      proverId: 0,
    },
    prover: {
      currentCapacity: 0,
      address: '',
      stakedAmount: BigNumber.from(0),
      amountStaked: BigNumber.from(0),
    },
    address: '',
  };
  try {
    const staker = await contract.getStaker(userAddress);

    if (staker.staker.proverId !== 0) {
      const prover = await contract.proverIdToAddress(staker.staker.proverId);
      resp.prover = prover;
      resp.staker = staker.staker;
      resp.prover = staker.prover;
      resp.address = prover;
    }
  } catch (e) {
    console.error(e);
  }
  return resp;
};
