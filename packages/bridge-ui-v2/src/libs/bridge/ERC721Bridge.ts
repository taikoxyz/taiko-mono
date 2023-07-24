import type { Hex } from 'viem';

import type { Bridge } from './types';

export class ERC721Bridge implements Bridge {
  async estimateGas(): Promise<bigint> {
    return Promise.resolve(BigInt(0));
  }

  async bridge(): Promise<Hex> {
    return Promise.resolve('0x');
  }
}
