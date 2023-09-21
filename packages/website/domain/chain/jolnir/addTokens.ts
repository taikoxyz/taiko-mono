import { AddTokenParameter } from "../baseTypes";
import { JOLNIR_CONFIG } from "./config";

export const JOLNIR_ADD_TTKOJ: AddTokenParameter = {
  address:
    JOLNIR_CONFIG.rollupContracts.erc20Contracts.bridgedTaikoToken.address.impl,
  symbol: JOLNIR_CONFIG.rollupContracts.erc20Contracts.bridgedTaikoToken.symbol,
  decimals:
    JOLNIR_CONFIG.rollupContracts.erc20Contracts.bridgedTaikoToken.decimals,
  image:
    "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/ttko.svg",
};

export const JOLNIR_ADD_HORSE: AddTokenParameter = {
  address:
    JOLNIR_CONFIG.rollupContracts.erc20Contracts.bridgedHorseToken.address.impl,
  symbol: JOLNIR_CONFIG.rollupContracts.erc20Contracts.bridgedHorseToken.symbol,
  decimals:
    JOLNIR_CONFIG.rollupContracts.erc20Contracts.bridgedHorseToken.decimals,
  image:
    "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/horse.svg",
};

export const JOLNIR_ADD_TOKENS = [
  JOLNIR_ADD_TTKOJ,
  JOLNIR_ADD_HORSE,
];
