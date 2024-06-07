import { hardhat, holesky } from '@wagmi/core/chains';

import { taiko } from '$wagmi-config';

import { default as HardhatWhitelist } from '../../generated/whitelist/hardhat.json';
import { default as HoleskyWhitelist } from '../../generated/whitelist/holesky.json';
import { default as TaikoWhitelist } from '../../generated/whitelist/mainnet.json';

export const whitelist: Record<number, any> = {
  [hardhat.id]: HardhatWhitelist,
  [holesky.id]: HoleskyWhitelist,
  [taiko.id]: TaikoWhitelist,
};
