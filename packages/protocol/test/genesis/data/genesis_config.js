"use strict";
const ADDRESS_LENGTH = 40;

module.exports = {
  // Owner address of the pre-deployed L2 contracts.
  contractOwner: "0x91c34396e640e3bB4eE80f2e523c23dDa2b3f78F",
  l1ChainId: 7014190335,
  chainId: 167010,
  // Account address and pre-mint ETH amount as key-value pairs.
  seedAccounts: [
    { "0x91c34396e640e3bB4eE80f2e523c23dDa2b3f78F": 1000 },
    { "0x79fcdef22feed20eddacbb2587640e45491b757f": 1000 },
  ],
  // Owner Chain ID, Security Council, and Timelock Controller
  l1ChainId: 31337,
  ownerSecurityCouncil: "0x91c34396e640e3bB4eE80f2e523c23dDa2b3f78F",
  ownerTimelockController: "0x91c34396e640e3bB4eE80f2e523c23dDa2b3f78F",
  get contractAddresses() {
    return {
      // ============ Implementations ============
      // Shared Contracts
      BridgeImpl: getConstantAddress(`0${this.chainId}`, 1),
      ERC20VaultImpl: getConstantAddress(`0${this.chainId}`, 2),
      ERC721VaultImpl: getConstantAddress(`0${this.chainId}`, 3),
      ERC1155VaultImpl: getConstantAddress(`0${this.chainId}`, 4),
      SignalServiceImpl: getConstantAddress(`0${this.chainId}`, 5),
      SharedAddressManagerImpl: getConstantAddress(`0${this.chainId}`, 6),
      BridgedERC20Impl: getConstantAddress(`0${this.chainId}`, 10096),
      BridgedERC721Impl: getConstantAddress(`0${this.chainId}`, 10097),
      BridgedERC1155Impl: getConstantAddress(`0${this.chainId}`, 10098),
      RegularERC20: getConstantAddress(`0${this.chainId}`, 10099),
      // Rollup Contracts
      TaikoL2Impl: getConstantAddress(`0${this.chainId}`, 10001),
      RollupAddressManagerImpl: getConstantAddress(`0${this.chainId}`, 10002),
      // ============ Proxies ============
      // Shared Contracts
      Bridge: getConstantAddress(this.chainId, 1),
      ERC20Vault: getConstantAddress(this.chainId, 2),
      ERC721Vault: getConstantAddress(this.chainId, 3),
      ERC1155Vault: getConstantAddress(this.chainId, 4),
      SignalService: getConstantAddress(this.chainId, 5),
      SharedAddressManager: getConstantAddress(this.chainId, 6),
      // Rollup Contracts
      TaikoL2: getConstantAddress(this.chainId, 10001),
      RollupAddressManager: getConstantAddress(this.chainId, 10002),
    };
  },
  // L2 EIP-1559 baseFee calculation related fields.
  param1559: {
    gasExcess: 0,
  },
  // Option to pre-deploy an ERC-20 token.
  predeployERC20: true,
};

function getConstantAddress(prefix, suffix) {
  return `0x${prefix}${"0".repeat(
    ADDRESS_LENGTH - String(prefix).length - String(suffix).length,
  )}${suffix}`;
}
