import { BigNumber, Contract, ethers } from 'ethers';
import type { Prover } from '../domain/prover';
import type { Staker } from '../domain/staker';
import ProverPool from '../constants/abi/ProverPool';

export const getProverRequirements = async (
  provider: ethers.providers.Provider,
  contractAddress: string,
) => {
  const contract: Contract = new Contract(
    contractAddress,
    ProverPool,
    provider,
  );

  const minStakePerCapacity = await contract.MIN_STAKE_PER_CAPACITY();
  const minCapacity = await contract.MAX_CAPACITY_LOWER_BOUND();

  return { minStakePerCapacity, minCapacity };
};
