import { taiko, taikoHekla } from '@wagmi/core/chains';

import { default as HeklaWhitelist } from '../../generated/whitelist/hekla.json';
import { default as TaikoWhitelist } from '../../generated/whitelist/mainnet.json';

export const whitelist: Record<number, any> = {
  [taikoHekla.id]: HeklaWhitelist,
  [taiko.id]: TaikoWhitelist,
};
