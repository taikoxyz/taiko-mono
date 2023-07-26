import type { Hash, Hex } from 'viem';

import { Bridge } from './Bridge';

export class ERC721Bridge extends Bridge {
  async estimateGas(): Promise<bigint> {
    return Promise.resolve(BigInt(0));
  }

  async bridge(): Promise<Hex> {
    return Promise.resolve('0x');
  }

  async claim() {
    return Promise.resolve('0x' as Hash);
  }

  async release() {
    return Promise.resolve('0x' as Hash);
  }
}
