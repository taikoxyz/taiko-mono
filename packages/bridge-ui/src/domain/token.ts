import Eth from "../components/icons/ETH.svelte";
import type { ComponentType } from "svelte";
import Tko from "../components/icons/TKO.svelte";

export type Token = {
  name: string;
  address: string;
  symbol: string;
  decimals: number;
  logoUrl?: string;
  logoComponent: ComponentType;
};

export const ETH: Token = {
  name: "Ethereum",
  address: "0x00",
  decimals: 18,
  symbol: "ETH",
  logoComponent: Eth,
};

export const TKO: Token = {
  name: "Taiko",
  address: "0x00",
  decimals: 18,
  symbol: "TKO",
  logoComponent: Tko,
};

export const HORSE: Token = {
  name: "Horse Token",
  address: "0xa196769Ca67f4903eCa574F5e76e003071A4d84a",
  decimals: 18,
  symbol: "HORSE",
  logoComponent: Tko,
};

export const tokens = [ETH, TKO, HORSE];
