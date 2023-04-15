import { ethers } from "ethers";
import type { Status } from "src/domain/status";

export const displayStatusValue = (value: Status) => {
  if (typeof value === "string") {
    if (!value) return "0x";
    if (ethers.utils.isHexString(value)) {
      return value.substring(0, 14);
    }
    return value;
  }

  if (typeof value === "number") return value;
  if (typeof value === "boolean") return value.toString();
};
