"use strict";
const ADDRESS_LENGTH = 40;

module.exports = {
  contractOwner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  contractAdmin: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  chainId: 167,
  seedAccounts: [
    {
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266": 1024,
    },
    {
      "0x70997970C51812dc3A010C7d01b50e0d17dc79C8": 1024,
    },
    {
      "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC": 1024,
    },
    {
      "0x90F79bf6EB2c4f870365E785982E1f101E93b906": 1024,
    },
    {
      "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65": 1024,
    },
    {
      "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc": 1024,
    },
    {
      "0x976EA74026E726554dB657fA54763abd0C3a0aa9": 1024,
    },
    {
      "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955": 1024,
    },
    {
      "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f": 1024,
    },
    {
      "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720": 1024,
    },
    {
      "0xBcd4042DE499D14e55001CcbB24a551F3b954096": 1024,
    },
    {
      "0x71bE63f3384f5fb98995898A86B02Fb2426c5788": 1024,
    },
    {
      "0xFABB0ac9d68B0B445fB7357272Ff202C5651694a": 1024,
    },
    {
      "0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec": 1024,
    },
    {
      "0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097": 1024,
    },
    {
      "0xcd3B766CCDd6AE721141F452C550Ca635964ce71": 1024,
    },
    {
      "0x2546BcD3c84621e976D8185a91A922aE77ECEc30": 1024,
    },
    {
      "0xbDA5747bFD65F08deb54cb465eB87D40e51B197E": 1024,
    },
    {
      "0xdD2FD4581271e230360230F9337D5c0430Bf44C0": 1024,
    },
    {
      "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199": 1024,
    },
    {
      "0x7D86687F980A56b832e9378952B738b614A99dc6": 1024,
    },
    {
      "0x11e8F3eA3C6FcF12EcfF2722d75CEFC539c51a1C": 1024,
    },
    {
      "0x9eAF5590f2c84912A08de97FA28d0529361Deb9E": 1024,
    },
    {
      "0x1003ff39d25F2Ab16dBCc18EcE05a9B6154f65F4": 1024,
    },
  ],
  get contractAddresses() {
    // ============ Implementations ============
    // Singletons
    return {
      Bridge: getConstantAddress(`0${this.chainId}`, 1),
      ProxiedSingletonERC20Vault: getConstantAddress(`0${this.chainId}`, 2),
      ProxiedSingletonERC721Vault: getConstantAddress(`0${this.chainId}`, 3),
      ProxiedSingletonERC1155Vault: getConstantAddress(`0${this.chainId}`, 4),
      SignalService: getConstantAddress(`0${this.chainId}`, 5),
      ProxiedSingletonAddressManagerForSingletons: getConstantAddress(
        `0${this.chainId}`,
        6,
      ),
      // Non-singletons
      ProxiedSingletonTaikoL2: getConstantAddress(`0${this.chainId}`, 10001),
      AddressManager: getConstantAddress(`0${this.chainId}`, 10002),
      ProxiedBridgedERC20: getConstantAddress(`0${this.chainId}`, 10096),
      ProxiedBridgedERC721: getConstantAddress(`0${this.chainId}`, 10097),
      ProxiedBridgedERC1155: getConstantAddress(`0${this.chainId}`, 10098),
      RegularERC20: getConstantAddress(`0${this.chainId}`, 10099),
      // ============ Proxies ============
      // Singletons
      SingletonBridgeProxy: getConstantAddress(this.chainId, 1),
      SingletonERC20VaultProxy: getConstantAddress(this.chainId, 2),
      SingletonERC721VaultProxy: getConstantAddress(this.chainId, 3),
      SingletonERC1155VaultProxy: getConstantAddress(this.chainId, 4),
      SingletonSignalServiceProxy: getConstantAddress(this.chainId, 5),
      SingletonAddressManagerForSingletonsProxy: getConstantAddress(
        this.chainId,
        6,
      ),
      // Non-singletons
      SingletonTaikoL2Proxy: getConstantAddress(this.chainId, 10001),
      AddressManagerProxy: getConstantAddress(this.chainId, 10002),
    };
  },
  param1559: {
    gasExcess: 1,
  },
  predeployERC20: true,
};

function getConstantAddress(prefix, suffix) {
  return `0x${prefix}${"0".repeat(
    ADDRESS_LENGTH - String(prefix).length - String(suffix).length,
  )}${suffix}`;
}
