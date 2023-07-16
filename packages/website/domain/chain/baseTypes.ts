interface ContractProps {
  name: string;
}

interface ERC20Props {
  decimals: number;
  symbol: string;
}

interface Contract extends ContractProps {
  address: `0x${string}`;
}

interface ProxyContract extends ContractProps {
  address: {
    proxy: `0x${string}`;
    implementation: `0x${string}`;
  };
}

interface ERC20Contract extends Contract, ERC20Props {}

interface ProxyERC20Contract extends ProxyContract, ERC20Props {}

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
    name: string;
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
interface L1Contracts {
  addressManager: ProxyContract;
  taikoL1: ProxyContract;
  tokenVault: ProxyContract;
  bridge: ProxyContract;
  signalService: ProxyContract;
  plonkVerifier: Contract;
  proverPool?: ProxyContract; // optional since it's not present in all alpha versions
  taikoToken: ProxyERC20Contract;
  horseToken: ERC20Contract;
  bullToken: ERC20Contract;
}

interface L2Contracts {
  taikoL2: Contract;
  tokenVault: Contract;
  etherVault: Contract;
  bridge: Contract;
  signalService: Contract;
  bridgedTaikoToken: ERC20Contract;
  bridgedHorseToken: ERC20Contract;
  bridgedBullToken: ERC20Contract;
}

interface TaikoL1Alpha3 extends Network {
  l1Contracts: L1Contracts;
  otherContracts: readonly Contract[];
}

interface TaikoL1Alpha4 extends Network {
  l1Contracts: L1Contracts & { proverPool: ProxyContract };
  otherContracts: readonly Contract[];
}

interface TaikoL2Alpha3 extends Network {
  l2Contracts: L2Contracts;
  otherContracts: readonly Contract[];
}

type TaikoL2Alpha4 = TaikoL2Alpha3;

export type {
  AddEthereumChainParameter,
  TaikoL1Alpha3,
  TaikoL1Alpha4,
  TaikoL2Alpha3,
  TaikoL2Alpha4,
};
