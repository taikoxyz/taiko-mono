import { hardhat } from '@wagmi/core/chains';

import { default as HardhatWhitelist } from '../../generated/whitelist/hardhat.json';

export const whitelist: Record<number, any> = {
  [hardhat.id]: HardhatWhitelist,
};
