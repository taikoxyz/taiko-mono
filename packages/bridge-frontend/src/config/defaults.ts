export const DEFAULT_FROM_CHAIN_ID = 31336;
export const DEFAULT_TO_CHAIN_ID = 167001;
export const DEFAULT_TOKEN = {
  name: "Ether",
  address: "0x0000000000000000000000000000000000000000",
  chainId: 31336,
  symbol: "ETH",
  decimals: 18,
  logoUrl:
    "https://github.com/trustwallet/assets/blob/master/blockchains/ethereum/info/logo.png?raw=true",
};
export const CONTRACT_ADDRESS: Record<number, any> = {
  31336: {
    tokenVault: "0xDA1Ea1362475997419D2055dD43390AEE34c6c37",
  },
  167001: {
    tokenVault: "0x0ba868fEbD76DE70a9e66066f4b4B345aAb5832C",
  },
};
