import type { BridgeTransaction } from "./transactions";

export interface RelayerAPI {
  GetAllByAddress(
    address: string,
    chainID?: number
  ): Promise<BridgeTransaction[]>;

  GetBlockInfo(): Promise<Map<string, RelayerBlockInfo>>;
}

export type RelayerBlockInfo = {
  chainId: number;
  latestProcessedBlock: number;
  latestBlock: number;
}