import { BigNumber, Contract, ethers } from 'ethers';
import TaikoL1 from '../constants/abi/TaikoL1';

export const getTaikoL1Balance = async (
  provider: ethers.providers.Provider,
  contractAddress: string,
  userAddress: string,
): Promise<BigNumber> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  return await contract.getTaikoTokenBalance(userAddress);
};
