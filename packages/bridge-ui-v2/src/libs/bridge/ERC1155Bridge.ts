import type { Bridge } from './types';

export class ERC1155Bridge implements Bridge {
  async estimateGas(): Promise<bigint> {
    return Promise.resolve(BigInt(0));
  }
}
