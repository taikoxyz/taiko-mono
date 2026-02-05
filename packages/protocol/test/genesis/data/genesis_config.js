"use strict";
const ADDRESS_LENGTH = 40;

// Environment variable configuration with defaults
const CONTRACT_OWNER =
  process.env.CONTRACT_OWNER || "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39";
const CHAIN_ID = parseInt(process.env.CHAIN_ID || "167", 10);
const L1_CHAIN_ID = parseInt(process.env.L1_CHAIN_ID || "31337", 10);
// Comma-separated list of addresses to prefund
const SEED_ADDRESSES = process.env.SEED_ADDRESSES || process.env.SEED_ADDRESS || "";
// Comma-separated list of amounts (must match number of addresses, or single value applied to all)
const SEED_AMOUNTS = process.env.SEED_AMOUNTS || process.env.SEED_AMOUNT || "1000";
const REMOTE_SIGNAL_SERVICE =
  process.env.REMOTE_SIGNAL_SERVICE ||
  "0x0000000000000000000000000000000000000000";

// Parse seed accounts from comma-separated environment variables
function parseSeedAccounts(addresses, amounts) {
  if (!addresses || addresses.trim() === "") {
    return [];
  }

  const addressList = addresses.split(",").map((addr) => addr.trim()).filter(Boolean);
  const amountList = amounts.split(",").map((amt) => parseInt(amt.trim(), 10));

  // If single amount provided, apply to all addresses
  const useUniformAmount = amountList.length === 1 && addressList.length > 1;

  return addressList.map((address, index) => ({
    [address]: useUniformAmount ? amountList[0] : (amountList[index] || 0),
  }));
}

module.exports = {
  // Owner address of the pre-deployed L2 contracts.
  contractOwner: CONTRACT_OWNER,
  // Chain ID of the Taiko L2 network.
  chainId: CHAIN_ID,
  // Account address and pre-mint ETH amount as key-value pairs.
  seedAccounts: parseSeedAccounts(SEED_ADDRESSES, SEED_AMOUNTS),
  // Owner Chain ID, Security Council, and Timelock Controller
  l1ChainId: L1_CHAIN_ID,
  get contractAddresses() {
    return {
      // ============ Implementations ============
      // Shared Contracts
      BridgeImpl: getConstantAddress(`0${this.chainId}`, 1),
      ERC20VaultImpl: getConstantAddress(`0${this.chainId}`, 2),
      ERC721VaultImpl: getConstantAddress(`0${this.chainId}`, 3),
      ERC1155VaultImpl: getConstantAddress(`0${this.chainId}`, 4),
      SignalServiceImpl: getConstantAddress(`0${this.chainId}`, 5),
      SharedResolverImpl: getConstantAddress(`0${this.chainId}`, 6),
      BridgedERC20Impl: getConstantAddress(`0${this.chainId}`, 10096),
      BridgedERC721Impl: getConstantAddress(`0${this.chainId}`, 10097),
      BridgedERC1155Impl: getConstantAddress(`0${this.chainId}`, 10098),
      RegularERC20: getConstantAddress(`0${this.chainId}`, 10099),
      // Rollup Contracts
      TaikoAnchorImpl: getConstantAddress(`0${this.chainId}`, 10001),
      RollupResolverImpl: getConstantAddress(`0${this.chainId}`, 10002),
      AnchorForkRouterImpl: getConstantAddress(`0${this.chainId}`, 10004),
      // ============ Proxies ============
      // Shared Contracts
      Bridge: getConstantAddress(this.chainId, 1),
      ERC20Vault: getConstantAddress(this.chainId, 2),
      ERC721Vault: getConstantAddress(this.chainId, 3),
      ERC1155Vault: getConstantAddress(this.chainId, 4),
      SignalService: getConstantAddress(this.chainId, 5),
      SharedResolver: getConstantAddress(this.chainId, 6),
      // Rollup Contracts
      TaikoAnchor: getConstantAddress(this.chainId, 10001),
      RollupResolver: getConstantAddress(this.chainId, 10002),
    };
  },
  // L2 EIP-1559 baseFee calculation related fields.
  param1559: {
    gasExcess: 1,
  },
  // Option to pre-deploy an ERC-20 token.
  predeployERC20: true,
  remoteSignalService: REMOTE_SIGNAL_SERVICE,
  pacayaTaikoAnchor: "0x0000000000000000000000000000000000000000",
};

function getConstantAddress(prefix, suffix) {
  return `0x${prefix}${"0".repeat(
    ADDRESS_LENGTH - String(prefix).length - String(suffix).length,
  )}${suffix}`;
}
