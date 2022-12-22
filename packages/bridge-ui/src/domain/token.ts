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

export const HORSE: Token = {
  name: "Horse Token",
  addresses: [
    {
      chainId: CHAIN_MAINNET.id,
      address: import.meta.env
        ? import.meta.env.VITE_TEST_ERC20_ADDRESS_MAINNET
        : "",
    },
    {
      chainId: CHAIN_TKO.id,
      address: "0x00",
    },
  ],
  decimals: 18,
  symbol: "HORSE",
  logoComponent: Horse,
};

export const tokens = [ETH, HORSE];
