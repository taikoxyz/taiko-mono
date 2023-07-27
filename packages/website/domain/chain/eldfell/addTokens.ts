import { AddTokenParameter } from "../baseTypes";
import { ELDFELL_CONFIG } from "./config";

export const ELDFELL_ADD_TTKO: AddTokenParameter = {
    address: ELDFELL_CONFIG.rollupContracts.erc20Contracts.bridgedTaikoToken.address.impl,
    symbol: ELDFELL_CONFIG.rollupContracts.erc20Contracts.bridgedTaikoToken.symbol,
    decimals: ELDFELL_CONFIG.rollupContracts.erc20Contracts.bridgedTaikoToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/ttko.svg"
};

export const ELDFELL_ADD_BLL: AddTokenParameter = {
    address: ELDFELL_CONFIG.rollupContracts.erc20Contracts.bridgedBullToken.address.impl,
    symbol: ELDFELL_CONFIG.rollupContracts.erc20Contracts.bridgedBullToken.symbol,
    decimals: ELDFELL_CONFIG.rollupContracts.erc20Contracts.bridgedBullToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/bull.svg"
};

export const ELDFELL_ADD_HORSE: AddTokenParameter = {
    address: ELDFELL_CONFIG.rollupContracts.erc20Contracts.bridgedHorseToken.address.impl,
    symbol: ELDFELL_CONFIG.rollupContracts.erc20Contracts.bridgedHorseToken.symbol,
    decimals: ELDFELL_CONFIG.rollupContracts.erc20Contracts.bridgedHorseToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/horse.svg"
};

export const ELDFELL_ADD_TOKENS = [
    ELDFELL_ADD_TTKO,
    ELDFELL_ADD_BLL,
    ELDFELL_ADD_HORSE
]


