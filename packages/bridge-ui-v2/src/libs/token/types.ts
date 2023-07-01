export type Token = {
  name: string;
  addresses: Record<string, string>;
  symbol: string;
  decimals: number;
};

export type TokenEnv = {
  name: string;
  address: string;
  symbol: string;
};
