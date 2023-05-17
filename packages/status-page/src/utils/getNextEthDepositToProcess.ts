import { Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getNextEthDepositToProcess = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const stateVariables = await contract.getStateVariables();
  return stateVariables.nextEthDepositToProcess.toNumber();
};
