import { BigNumber, ethers } from "ethers";

export const getPeerCount = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const peers = await provider.send("net_peerCount", []);
  return BigNumber.from(peers).toNumber();
};
