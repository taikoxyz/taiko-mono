import { BigNumber, ethers } from "ethers";

export const getNetVersion = async (
  provider: ethers.providers.JsonRpcProvider
): Promise<number> => {
  const n = await provider.send("net_version", []);
  return BigNumber.from(n).toNumber();
};
