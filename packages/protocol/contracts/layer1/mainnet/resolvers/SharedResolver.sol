// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/LibStrings.sol";
import "src/shared/common/LibNetwork.sol";
import "src/shared/common/ResolverBase.sol";

/// @title SharedResolver
/// @dev Resolver used by multiple based rollups.
/// @custom:security-contact security@taiko.xyz
contract SharedResolver is ResolverBase {
    function getAddress(uint256 _chainId, bytes32 _name) internal pure override returns (address) {
        if (_chainId == LibNetwork.ETHEREUM_MAINNET) {
            if (_name == LibStrings.B_TAIKO_TOKEN) {
                return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
            }
            if (_name == LibStrings.B_QUOTA_MANAGER) {
                return 0x91f67118DD47d502B1f0C354D0611997B022f29E;
            }
            if (_name == LibStrings.B_BRIDGE) {
                return 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
            }
            if (_name == LibStrings.B_BRIDGED_ERC20) {
                return 0x65666141a541423606365123Ed280AB16a09A2e1;
            }
            if (_name == LibStrings.B_BRIDGED_ERC721) {
                return 0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7;
            }
            if (_name == LibStrings.B_BRIDGED_ERC1155) {
                return 0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40;
            }
            if (_name == LibStrings.B_ERC20_VAULT) {
                return 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab;
            }
            if (_name == LibStrings.B_ERC721_VAULT) {
                return 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa;
            }
            if (_name == LibStrings.B_ERC1155_VAULT) {
                return 0xaf145913EA4a56BE22E120ED9C24589659881702;
            }
            if (_name == LibStrings.B_SIGNAL_SERVICE) {
                return 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C;
            }
        } else if (_chainId == LibNetwork.TAIKO_MAINNET) {
            if (_name == LibStrings.B_BRIDGE) {
                return 0x1670000000000000000000000000000000000001;
            }
            if (_name == LibStrings.B_ERC20_VAULT) {
                return 0x1670000000000000000000000000000000000002;
            }
            if (_name == LibStrings.B_ERC721_VAULT) {
                return 0x1670000000000000000000000000000000000003;
            }
            if (_name == LibStrings.B_ERC1155_VAULT) {
                return 0x1670000000000000000000000000000000000004;
            }
            if (_name == LibStrings.B_SIGNAL_SERVICE) {
                return 0x1670000000000000000000000000000000000005;
            }
        }
        return address(0);
    }
}
