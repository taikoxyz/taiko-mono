import { hardhat, holesky, sepolia } from '@wagmi/core/chains';

import { default as HardhatWhitelist } from '../../generated/whitelist/hardhat.json';
import { default as HoleskyWhitelist } from '../../generated/whitelist/holesky.json';
import { default as SepoliaWhitelist } from '../../generated/whitelist/sepolia.json';

export const whitelist: Record<number, any> = {
  [hardhat.id]: HardhatWhitelist,
  [holesky.id]: HoleskyWhitelist,
  [sepolia.id]: SepoliaWhitelist,
};
