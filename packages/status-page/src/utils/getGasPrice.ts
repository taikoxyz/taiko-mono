import { ethers } from "ethers";

export const getGasPrice = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<string> => {
  const gasPrice = await provider.getGasPrice();
  return ethers.utils.formatUnits(gasPrice, "gwei");
};
