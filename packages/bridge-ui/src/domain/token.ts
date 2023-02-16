import Eth from "../components/icons/ETH.svelte";
import type { ComponentType } from "svelte";
import Tko from "../components/icons/TKO.svelte";
import { CHAIN_MAINNET, CHAIN_TKO } from "./chain";
import Horse from "../components/icons/Horse.svelte";

type Address = {
  chainId: number;
  address: string;
};
export type Token = {
  name: string;
  addresses: Address[];
  symbol: string;
  decimals: number;
  logoUrl?: string;
  logoComponent: ComponentType;
};

export const ETH: Token = {
  name: "Ethereum",
  addresses: [
    {
      chainId: CHAIN_MAINNET.id,
      address: "0x00",
    },
    {
      chainId: CHAIN_TKO.id,
      address: "0x00",
    },
  ],
  decimals: 18,
  symbol: "ETH",
  logoComponent: Eth,
};

export const TKO: Token = {
  name: "Taiko",
  addresses: [
    {
      chainId: CHAIN_MAINNET.id,
      address: "0x00",
    },
    {
      chainId: CHAIN_TKO.id,
      address: "0x00",
    },
  ],
  decimals: 18,
  symbol: "TKO",
  logoComponent: Tko,
};

export const TEST_ERC20: Token = {
  name: import.meta.env ? import.meta.env.VITE_TEST_ERC20_NAME_MAINNET : "Bull Token",
  addresses: [
    {
      chainId: CHAIN_MAINNET.id,
      address: import.meta.env
        ? import.meta.env.VITE_TEST_ERC20_ADDRESS_MAINNET
        : "0x1B5Ccd66cc2408A0084047720167F6234Dc5498A",
    },
    {
      chainId: CHAIN_TKO.id,
      address: "0x00",
    },
  ],
  decimals: 18,
  symbol: import.meta.env ? import.meta.env.VITE_TEST_ERC20_SYMBOL_MAINNET : "BULL",
  logoComponent: Horse,
};

export interface TokenStore {
  StoreToken(
    token: Token,
    address: string
  ): Promise<Token[]>;
  GetTokens(address: string): Token[],
  RemoveToken(token: Token, address: string): Token[],
}

export const tokens = [ETH, TEST_ERC20];
