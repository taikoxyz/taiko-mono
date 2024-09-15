module.exports = {
  // Owner address of the pre-deployed L2 contracts.
  contractOwner: "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
  // Chain ID of the Taiko L2 network.
  chainId: 167,
  // Account address and pre-mint ETH amount as key-value pairs.
  seedAccounts: [
    { "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39": 1024 },
    { "0x79fcdef22feed20eddacbb2587640e45491b757f": 1024 },
  ],
  // Owner Chain ID, Security Council, and Timelock Controller
  l1ChainId: 31337,
  ownerSecurityCouncil: "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
  ownerTimelockController: "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
  // L2 EIP-1559 baseFee calculation related fields.
  param1559: {
    gasExcess: 1,
  },
  // Option to pre-deploy an ERC-20 token.
  predeployERC20: true,
};
