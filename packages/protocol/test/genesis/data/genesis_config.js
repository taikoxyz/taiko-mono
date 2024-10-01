"use strict";
const ADDRESS_LENGTH = 40;

module.exports = {
  // Owner address of the pre-deployed L2 contracts.
  contractOwner: "0x6282E3B5475Ad6d502917661bD3BeD8696Cf0d12",
  // Chain ID of the Taiko L2 network.
  chainId: 167200,
  // Account address and pre-mint ETH amount as key-value pairs.
  seedAccounts: [
    { "0x6282E3B5475Ad6d502917661bD3BeD8696Cf0d12": 10240 },
    { "0xfc612094563ed102C1ba91E2A4D77B3AcF5A6B3A": 10240 },
  ],
  // Owner Chain ID, Security Council, and Timelock Controller
  l1ChainId: 7014190335,
  ownerSecurityCouncil: "0x6282E3B5475Ad6d502917661bD3BeD8696Cf0d12",
  ownerTimelockController: "0x6282E3B5475Ad6d502917661bD3BeD8696Cf0d12",
  // L2 EIP-1559 baseFee calculation related fields.
  param1559: {
    gasExcess: 1,
  },
  // Option to pre-deploy an ERC-20 token.
  predeployERC20: true,
};

function getConstantAddress(prefix, suffix) {
  return `0x${prefix}${"0".repeat(
    ADDRESS_LENGTH - String(prefix).length - String(suffix).length,
  )}${suffix}`;
}
