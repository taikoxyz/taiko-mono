import { BigNumber, Contract, ethers } from 'ethers';
import ERC20 from '../constants/abi/ERC20';

export const getTTKOBalance = async (
  provider: ethers.providers.Provider,
  contractAddress: string,
  userAddress: string,
): Promise<BigNumber> => {
  const contract: Contract = new Contract(contractAddress, ERC20, provider);
  return await contract.balanceOf(userAddress);
};
