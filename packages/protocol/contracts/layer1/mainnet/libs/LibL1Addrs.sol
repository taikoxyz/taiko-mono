// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibL1Addrs
/// @custom:security-contact security@taiko.xyz
library LibL1Addrs {
    address public constant DAO = 0x9CDf589C941ee81D75F34d3755671d614f7cf261;
    address public constant DAO_CONTROLLER = 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a;
    address public constant FORCED_INCLUSION_STORE = 0x05d88855361808fA1d7fc28084Ef3fCa191c4e03;
    address public constant TAIKO_WRAPPER = 0x9F9D2fC7abe74C79f86F0D1212107692430eef72;
    address public constant INBOX = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
    address public constant BRIDGE = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
    address public constant TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    address public constant SIGNAL_SERVICE = 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C;
    address public constant ERC20_VAULT = 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab;
    address public constant ERC721_VAULT = 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa;
    address public constant ERC1155_VAULT = 0xaf145913EA4a56BE22E120ED9C24589659881702;
    address public constant BRIDGED_ERC20 = 0x65666141a541423606365123Ed280AB16a09A2e1;
    address public constant BRIDGED_ERC721 = 0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7;
    address public constant BRIDGED_ERC1155 = 0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40;

    // Third-party addresses
    address public constant ENS_REVERSE_REGISTRAR = 0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb;
    address public constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
}
