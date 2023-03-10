import type { BridgeTransaction } from './transactions';

export interface RelayerAPI {
  GetAllByAddress(
    address: string,
    chainID?: number,
  ): Promise<BridgeTransaction[]>;

  GetBlockInfo(): Promise<Map<number, RelayerBlockInfo>>;
}

export type RelayerBlockInfo = {
  chainId: number;
  latestProcessedBlock: number;
  latestBlock: number;
};
