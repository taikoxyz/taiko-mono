import { BigNumber, Contract, ethers } from 'ethers';
import TaikoL1 from '../constants/abi/TaikoL1';

export const withdrawTaikoToken = async (
  signer: ethers.Signer,
  contractAddress: string,
  amount: BigNumber,
): Promise<ethers.Transaction> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, signer);
  return await contract.withdrawTaikoToken(amount);
};
