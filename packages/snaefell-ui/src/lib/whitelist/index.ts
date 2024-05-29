import { hardhat } from '@wagmi/core/chains';

import { taiko } from '$wagmi-config';

import { default as HardhatWhitelist } from '../../generated/whitelist/hardhat.json';
import { default as MainnetWhitelist } from '../../generated/whitelist/mainnet.json';

export const whitelist: Record<number, any> = {
  [hardhat.id]: HardhatWhitelist,
  [taiko.id]: MainnetWhitelist,
};
