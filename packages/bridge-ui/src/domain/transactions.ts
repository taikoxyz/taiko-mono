export type BridgeTransaction = {
  id: number;
  name: string;
  data: string;
  status: number;
  chainID: number;
};

export interface Transactioner {
  GetAllByAddress(
    address: string,
    chainID: number
  ): Promise<BridgeTransaction[]>;
}
