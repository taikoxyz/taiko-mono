import { BigNumber, ethers } from "ethers";

export const getPeers = async (
  provider: ethers.providers.JsonRpcProvider
): Promise<number> => {
  const peers = await provider.send("net_peerCount", []);
  return BigNumber.from(peers).toNumber();
};
