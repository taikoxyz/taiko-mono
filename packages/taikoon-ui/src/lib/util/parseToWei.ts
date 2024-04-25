import { parseUnits } from 'viem';

export function parseToWei(strEther?: string) {
  return parseUnits(strEther ?? '0', 18);
}
