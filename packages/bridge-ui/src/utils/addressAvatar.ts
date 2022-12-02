import Identicon from "identicon.js";
import { ethers } from "ethers";

export const DEFAULT_IDENTICON = new Identicon(
  "c157a79031e1c40f85931829bc5fc552",
  {
    foreground: [0, 0, 0, 255],
    background: [255, 255, 255, 255],
    margin: 0.2,
    size: 420,
  }
).toString();

export const getAddressAvatarFromIdenticon = (address: string): string => {
  if (!address || !ethers.utils.isAddress(address)) {
    return DEFAULT_IDENTICON;
  }

  const data = new Identicon(address, 420).toString();
  return data;
};
