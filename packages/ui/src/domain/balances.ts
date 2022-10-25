import type { BigNumber } from "ethers";

type GetTokenBalancesOpts = {
  account: string;
  contractAddresses?: string[];
  chainId: number;
};

type GetNFTBalancesOpts = {
  account: string;
  contractAddresses?: string[];
  chainId: number;
};

type TokenBalance = {
  contractAddress: string;
  amount: BigNumber;
};

enum NFTMediaType {
  Video,
  ThreeD,
  Audio,
  Interactive,
  Image,
}

enum NFTType {
  ERC721 = "ERC721",
  ERC1155 = "ERC1155",
}
type NFTBalance = {
  amount: BigNumber;
  title: string;
  description: string;
  tokenUri: string;
  image: string;
  attributes: Array<Record<string, any>>;
  nftType: NFTType;
  tokenId: string;
  contractAddress: string;
};
interface TokenBalancer {
  GetTokenBalances(opts: GetTokenBalancesOpts): Promise<TokenBalance[]>;
  GetNFTBalances(opts: GetNFTBalancesOpts): Promise<NFTBalance[]>;
}

export {
  TokenBalancer,
  GetTokenBalancesOpts,
  TokenBalance,
  GetNFTBalancesOpts,
  NFTBalance,
  NFTType,
  NFTMediaType,
};
