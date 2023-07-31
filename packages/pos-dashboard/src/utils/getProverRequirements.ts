import { BigNumber, Contract, ethers } from 'ethers';
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
  const minCapacity = await contract.MIN_CAPACITY();

  return { minStakePerCapacity, minCapacity };
};
