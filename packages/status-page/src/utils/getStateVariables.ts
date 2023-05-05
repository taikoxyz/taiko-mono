import { BigNumber, Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

const cacheTime = 1000 * 15; // 15 seconds
type StateVarsCache = {
  cachedAt: number;
  stateVars: any;
};

let stateVarsCache: StateVarsCache;

export const getStateVariables = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
) => {
  if (stateVarsCache && stateVarsCache.cachedAt + cacheTime > Date.now()) {
    return stateVarsCache.stateVars;
  }

  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const vars = await contract.getStateVariables();
  stateVarsCache = {
    stateVars: vars,
    cachedAt: Date.now(),
  };
  return vars;
};
