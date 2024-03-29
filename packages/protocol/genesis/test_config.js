"use strict";
const ADDRESS_LENGTH = 40;

module.exports = {
  ownerTimelockController: "0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190",
  ownerSecurityCouncil: "0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190",
  l1ChainId: 17000,
  chainId: 167009,
  seedAccounts: [
    {
      "0xd26010814C620F80A70cbD58cE353A10fa05491a": 1024,
    },
    {
      "0xd2b932FaCeb6FB733394e8445050daE6c025F9Be": 1024,
    }
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
  param1559: {
    gasExcess: 20000000000,
  },
  predeployERC20: true,
};

function getConstantAddress(prefix, suffix) {
  return `0x${prefix}${"0".repeat(
    ADDRESS_LENGTH - String(prefix).length - String(suffix).length,
  )}${suffix}`;
}
