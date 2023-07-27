import { AddTokenParameter } from "../baseTypes";
import { SEPOLIA_CONFIG } from "./config";

export const SEPOLIA_ADD_TTKO: AddTokenParameter = {
    address: SEPOLIA_CONFIG.basedContracts.erc20Contracts.taikoToken.address.proxy,
    symbol: SEPOLIA_CONFIG.basedContracts.erc20Contracts.taikoToken.symbol,
    decimals: SEPOLIA_CONFIG.basedContracts.erc20Contracts.taikoToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/ttko.svg"
};

export const SEPOLIA_ADD_BLL: AddTokenParameter = {
    address: SEPOLIA_CONFIG.basedContracts.erc20Contracts.bullToken.address.impl,
    symbol: SEPOLIA_CONFIG.basedContracts.erc20Contracts.bullToken.symbol,
    decimals: SEPOLIA_CONFIG.basedContracts.erc20Contracts.bullToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/bull.svg"
};


export const SEPOLIA_ADD_HORSE: AddTokenParameter = {
    address: SEPOLIA_CONFIG.basedContracts.erc20Contracts.horseToken.address.impl,
    symbol: SEPOLIA_CONFIG.basedContracts.erc20Contracts.horseToken.symbol,
    decimals: SEPOLIA_CONFIG.basedContracts.erc20Contracts.horseToken.decimals,
    image: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/horse.svg"
};

export const SEPOLIA_ADD_TOKENS = [
    SEPOLIA_ADD_TTKO,
    SEPOLIA_ADD_BLL,
    SEPOLIA_ADD_HORSE
]



