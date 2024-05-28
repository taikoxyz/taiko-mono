import { hardhat } from '@wagmi/core/chains';

import { devnet, taiko } from '$wagmi-config';

import { default as DevnetWhitelist } from '../../generated/whitelist/devnet.json';
import { default as HardhatWhitelist } from '../../generated/whitelist/hardhat.json';
import { default as MainnetWhitelist } from '../../generated/whitelist/mainnet.json';

export const whitelist: Record<number, any> = {
  [hardhat.id]: HardhatWhitelist,
  [devnet.id]: DevnetWhitelist,
  [taiko.id]: MainnetWhitelist,
};
