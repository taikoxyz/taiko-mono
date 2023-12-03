import { ethers } from "ethers";
import type { Status } from "src/domain/status";

export const displayStatusValue = (value: Status) => {
  switch (typeof value) {
    case "string":
      if (!value) return "0x";
      if (ethers.utils.isHexString(value)) {
        return value.substring(0, 14);
      }
      return value;
    case "number":
      return value;
    case "boolean":
      return value.toString();
    default:
      throw new Error("Invalid status type");
  }
};
