import { parseUnits } from 'viem';

import { ETHToken } from '$libs/token';

export function parseToWei(strEther?: string) {
  return parseUnits(strEther ?? '0', ETHToken.decimals);
}
