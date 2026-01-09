import { type Address, zeroAddress } from 'viem';

import { routingContractsMap } from '$bridgeConfig';
import { type AddressConfig, ContractType, type GetContractAddressType } from '$libs/bridge';
import { TokenType } from '$libs/token';

const getVaultAddress = (args: GetContractAddressType): Address => {
  const addressConfig = routingContractsMap[args.srcChainId][args.destChainId];

  const addressGetters: Record<TokenType, (config: AddressConfig) => Address> = {
    [TokenType.ERC1155]: (config) => config.erc1155VaultAddress,
    [TokenType.ERC721]: (config) => config.erc721VaultAddress,
    [TokenType.ERC20]: (config) => config.erc20VaultAddress,
    [TokenType.ETH]: (config) => config.etherVaultAddress || zeroAddress,
  };

  if (!args.tokenType) throw new Error('Token type is required');
  const getAddress = addressGetters[args.tokenType];

  if (!getAddress) {
    throw new Error(`Unsupported token type: ${args.tokenType}`);
  }

  return getAddress(addressConfig);
};

export const getContractAddressByType = (args: GetContractAddressType): Address => {
  const addressConfig = routingContractsMap[args.srcChainId][args.destChainId];

  switch (args.contractType) {
    case ContractType.BRIDGE:
      return addressConfig.bridgeAddress;
    case ContractType.VAULT:
      return getVaultAddress(args);
    case ContractType.SIGNALSERVICE:
      return addressConfig.signalServiceAddress;
    case ContractType.CROSSCHAINSYNC:
      return addressConfig.crossChainSyncAddress;
    default:
      throw new Error('Invalid contract type');
  }
};
