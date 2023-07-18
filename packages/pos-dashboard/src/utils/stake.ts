import { BigNumber, Contract, ethers } from 'ethers';
import ProverPool from '../constants/abi/ProverPool';

export const stake = async (
  signer: ethers.Signer,
  contractAddress: string,
  amount: BigNumber,
  rewardPerGas: BigNumber,
  maxCapacity: BigNumber,
): Promise<ethers.Transaction> => {
  const contract: Contract = new Contract(contractAddress, ProverPool, signer);
  return await contract.stake(amount, rewardPerGas, maxCapacity);
};
