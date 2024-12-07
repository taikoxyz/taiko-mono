"use strict";
const ADDRESS_LENGTH = 40;

module.exports = {
  contractOwner: "0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be",
  l1ChainId: 1,
  chainId: 167000,
  seedAccounts: [
    {
      "0x69AA0361Dbb0527d4F1e5312403Bd41788fe61Fe": 199,
    },
    {
      "0x00000968bfe78aa27cd380d629d61c89bd6b03e8": 1,
    },
  ],
  get contractAddresses() {
    return {
      // ============ Implementations ============
      // Shared Contracts
      BridgeImpl: getConstantAddress(`0${this.chainId}`, 1),
      ERC20VaultImpl: getConstantAddress(`0${this.chainId}`, 2),
      ERC721VaultImpl: getConstantAddress(`0${this.chainId}`, 3),
      ERC1155VaultImpl: getConstantAddress(`0${this.chainId}`, 4),
      SignalServiceImpl: getConstantAddress(`0${this.chainId}`, 5),
      SharedDefaultResolverImpl: getConstantAddress(`0${this.chainId}`, 6),
      BridgedERC20Impl: getConstantAddress(`0${this.chainId}`, 10096),
      BridgedERC721Impl: getConstantAddress(`0${this.chainId}`, 10097),
      BridgedERC1155Impl: getConstantAddress(`0${this.chainId}`, 10098),
      // Rollup Contracts
      TaikoL2Impl: getConstantAddress(`0${this.chainId}`, 10001),
      RollupDefaultResolverImpl: getConstantAddress(`0${this.chainId}`, 10002),
      // ============ Proxies ============
      // Shared Contracts
      Bridge: getConstantAddress(this.chainId, 1),
      ERC20Vault: getConstantAddress(this.chainId, 2),
      ERC721Vault: getConstantAddress(this.chainId, 3),
      ERC1155Vault: getConstantAddress(this.chainId, 4),
      SignalService: getConstantAddress(this.chainId, 5),
      SharedDefaultResolver: getConstantAddress(this.chainId, 6),
      // Rollup Contracts
      TaikoL2: getConstantAddress(this.chainId, 10001),
      RollupDefaultResolver: getConstantAddress(this.chainId, 10002),
    };
  },
  param1559: {
    gasExcess: 1,
  },
  predeployERC20: false,
};

function getConstantAddress(prefix, suffix) {
  return `0x${prefix}${"0".repeat(
    ADDRESS_LENGTH - String(prefix).length - String(suffix).length,
  )}${suffix}`;
}
