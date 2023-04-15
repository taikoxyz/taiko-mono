import { ethers } from "ethers";
export const getEthBalance = async (
  provider: ethers.providers.JsonRpcProvider,
  address: string
): Promise<string> => {
  const b = await provider.getBalance(address);
  return ethers.utils.formatEther(b);
};
