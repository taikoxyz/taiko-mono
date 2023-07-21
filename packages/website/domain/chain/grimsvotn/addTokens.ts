import { AddTokenParameter } from "../baseTypes";
import { GRIMSVOTN_CONFIG } from "./config";

export const GRIMSVOTN_ADD_TTKO: AddTokenParameter = {
    address: GRIMSVOTN_CONFIG.rollupContracts.erc20Contracts.bridgedTaikoToken.address.impl,
    symbol: GRIMSVOTN_CONFIG.rollupContracts.erc20Contracts.bridgedTaikoToken.symbol,
    decimals: GRIMSVOTN_CONFIG.rollupContracts.erc20Contracts.bridgedTaikoToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/ttko.svg"
};

export const GRIMSVOTN_ADD_TTKOE: AddTokenParameter = {
    address: GRIMSVOTN_CONFIG.basedContracts.erc20Contracts.taikoToken.address.proxy,
    symbol: GRIMSVOTN_CONFIG.basedContracts.erc20Contracts.taikoToken.symbol,
    decimals: GRIMSVOTN_CONFIG.basedContracts.erc20Contracts.taikoToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/ttko.svg"
};

export const GRIMSVOTN_ADD_BLL: AddTokenParameter = {
    address: GRIMSVOTN_CONFIG.rollupContracts.erc20Contracts.bridgedBullToken.address.impl,
    symbol: GRIMSVOTN_CONFIG.rollupContracts.erc20Contracts.bridgedBullToken.symbol,
    decimals: GRIMSVOTN_CONFIG.rollupContracts.erc20Contracts.bridgedBullToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/bull.svg"
};

export const GRIMSVOTN_ADD_HORSE: AddTokenParameter = {
    address: GRIMSVOTN_CONFIG.rollupContracts.erc20Contracts.bridgedHorseToken.address.impl,
    symbol: GRIMSVOTN_CONFIG.rollupContracts.erc20Contracts.bridgedHorseToken.symbol,
    decimals: GRIMSVOTN_CONFIG.rollupContracts.erc20Contracts.bridgedHorseToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/horse.svg"
};

export const GRIMSVOTN_ADD_TOKENS = [
    GRIMSVOTN_ADD_TTKO,
    GRIMSVOTN_ADD_TTKOE,
    GRIMSVOTN_ADD_BLL,
    GRIMSVOTN_ADD_HORSE
]


