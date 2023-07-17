interface Contract {
  name: string;
  address: {
    proxy?: `0x${string}`;
    impl: `0x${string}`; // implementation
  };
}

interface ERC20Contract extends Contract {
  decimals: number;
  symbol: string;
}

// Generic network type
interface Network {
  names: {
    lowercaseShortName: string; // used as a tag / reference name
    shortName: string; // the most common colloquial name, like "Grimsvotn"
    shortishName: string; // slightly more expressive, like "Grimsvotn L2"
    mediumName: string; // even more expressive (good for wallets), like "Taiko Grimsvotn L2"
    longName: string; // fully descriptive name, be careful as the version can change, like "Taiko Grimsvotn L2 (alpha-3)"
  };
  chainId: {
    decimal: number;
    hex: string;
  };
  nativeCurrency: {
    name: "Ether";
    symbol: "ETH";
    decimals: 18;
  };
  rpc: {
    https: string;
    wss?: string;
  };
  blockExplorer: {
    name: "Blockscout" | "Etherscan";
    url: string;
  };
  testnet: boolean;
}

// Interface from EIP-3085: https://eips.ethereum.org/EIPS/eip-3085
interface AddEthereumChainParameter {
  chainId: string; // A 0x-prefixed hexadecimal string
  blockExplorerUrls?: string[];
  chainName?: string;
  iconUrls?: string[];
  nativeCurrency: {
    name: string;
    symbol: string; // 2-6 characters long
    decimals: number;
  };
  rpcUrls: string[];
}

// Taiko network types
interface BasedContracts {
  addressManager: Contract;
  taikoL1: Contract;
  tokenVault: Contract;
  bridge: Contract;
  signalService: Contract;
  plonkVerifier: Contract;
  proverPool?: Contract; // optional since it's not present in all alpha versions
  erc20Contracts?: {
    taikoToken?: ERC20Contract;
    horseToken?: ERC20Contract;
    bullToken?: ERC20Contract;
  };
}

interface RollupContracts {
  taikoL2: Contract;
  tokenVault: Contract;
  etherVault: Contract;
  bridge: Contract;
  signalService: Contract;
  erc20Contracts: {
    bridgedTaikoToken: ERC20Contract;
    bridgedHorseToken: ERC20Contract;
    bridgedBullToken: ERC20Contract;
  };
}

interface OtherContracts {
  deterministicDeploymentProxy?: Contract;
  erc4337Entrypoint?: Contract;
}

interface TaikoL1Alpha3 extends Network {
  basedContracts: BasedContracts;
  otherContracts: OtherContracts;
}

interface TaikoL1Alpha4 extends Network {
  basedContracts: BasedContracts & { proverPool: Contract };
  otherContracts: OtherContracts;
}

interface TaikoL2Alpha3 extends Network {
  rollupContracts: RollupContracts;
  otherContracts: OtherContracts;
}

type TaikoL2Alpha4 = TaikoL2Alpha3;

export type {
  AddEthereumChainParameter,
  TaikoL1Alpha3,
  TaikoL1Alpha4,
  TaikoL2Alpha3,
  TaikoL2Alpha4,
  BasedContracts,
  RollupContracts,
  OtherContracts,
};
