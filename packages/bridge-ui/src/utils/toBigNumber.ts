import { BigNumber } from "ethers";

// This will also handle scientific notation (or e notation: 2e+21)
export function toBigNumber(value: string | number | bigint | boolean): BigNumber {
  return BigNumber.from(BigInt(value).toString());
}
