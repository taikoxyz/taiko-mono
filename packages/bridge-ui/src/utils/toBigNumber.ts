import { BigNumber } from "ethers";

export function toBigNumber(value: string | number | bigint | boolean): BigNumber {
  return BigNumber.from(BigInt(value).toString());
}
