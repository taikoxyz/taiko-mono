import type { ethers } from "ethers";

export const getListening = async (
  provider: ethers.providers.JsonRpcProvider
): Promise<boolean> => {
  return await provider.send("net_listening", []);
};
