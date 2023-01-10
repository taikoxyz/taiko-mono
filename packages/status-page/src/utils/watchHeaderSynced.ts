import { Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const watchHeaderSynced = async (
  provider: ethers.providers.JsonRpcProvider,
  taikoL1Address: string,
  onEvent: (value: string | number | boolean) => void
) => {
  const contract: Contract = new Contract(taikoL1Address, TaikoL1, provider);
  contract.on("HeaderSynced", (height, srcHeight, srcHash) => {
    onEvent(srcHash);
  });
};
