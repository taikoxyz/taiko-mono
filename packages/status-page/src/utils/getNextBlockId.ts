import { BigNumber, Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getNextBlockId = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const stateVariables = await contract.getStateVariables();
  const nextBlockId = stateVariables.nextBlockId;
  return BigNumber.from(nextBlockId).toNumber();
};
