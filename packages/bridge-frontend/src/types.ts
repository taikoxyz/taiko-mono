export type Chain = {
  id: number;
  name: string;
  rpc: string;
  enabled?: boolean;
};

export type Token = {
  name: string;
  address: string;
  chainId: number;
  symbol: string;
  decimals: number;
  logoUrl?: string;
};
