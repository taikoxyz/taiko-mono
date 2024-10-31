"use strict";
const ADDRESS_LENGTH = 40;

module.exports = {
  // Owner address of the pre-deployed L2 contracts.
  contractOwner: "0xa26E6497100FACDa8827373D363D6E0ebD174f50",
  // Chain ID of the Taiko L2 network.
  chainId: 8787,
  // Account address and pre-mint ETH amount as key-value pairs.
  seedAccounts: [
    { "0xa26E6497100FACDa8827373D363D6E0ebD174f50": 100 },
    { "0xfc612094563ed102C1ba91E2A4D77B3AcF5A6B3A": 100 },
  ],
  // Owner Chain ID, Security Council, and Timelock Controller
  l1ChainId: 17000,
  ownerSecurityCouncil: "0xa26E6497100FACDa8827373D363D6E0ebD174f50",
  ownerTimelockController: "0xa26E6497100FACDa8827373D363D6E0ebD174f50",
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
