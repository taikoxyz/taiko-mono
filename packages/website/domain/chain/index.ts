import { JOLNIR_CONFIG } from "./jolnir/config";
import { JOLNIR_ADD_ETHEREUM_CHAIN } from "./jolnir/addEthereumChain";
import { JOLNIR_ADD_TOKENS } from "./jolnir/addTokens";

export { SEPOLIA_CONFIG } from "./sepolia/config";
export { GRIMSVOTN_CONFIG } from "./grimsvotn/config";
export { ELDFELL_CONFIG } from "./eldfell/config";
export { JOLNIR_CONFIG } from "./jolnir/config";

export { SEPOLIA_ADD_ETHEREUM_CHAIN } from "./sepolia/addEthereumChain";
export { GRIMSVOTN_ADD_ETHEREUM_CHAIN } from "./grimsvotn/addEthereumChain";
export { ELDFELL_ADD_ETHEREUM_CHAIN } from "./eldfell/addEthereumChain";
export { JOLNIR_ADD_ETHEREUM_CHAIN } from "./jolnir/addEthereumChain";

export { SEPOLIA_ADD_TOKENS } from "./sepolia/addTokens";
export { GRIMSVOTN_ADD_TOKENS } from "./grimsvotn/addTokens";
export { ELDFELL_ADD_TOKENS } from "./eldfell/addTokens";
export { JOLNIR_ADD_TOKENS } from "./jolnir/addTokens";

// alias abstract taiko config to a concrete config
export const TAIKO_CONFIG = JOLNIR_CONFIG;
export const TAIKO_ADD_ETHEREUM_CHAIN = JOLNIR_ADD_ETHEREUM_CHAIN;
export const TAIKO_ADD_TOKENS = JOLNIR_ADD_TOKENS;
