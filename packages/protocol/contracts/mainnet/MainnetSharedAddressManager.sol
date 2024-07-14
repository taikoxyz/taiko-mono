// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/AddressManager.sol";
import "../common/LibStrings.sol";

/// @title MainnetSharedAddressManager
/// @notice See the documentation in {IAddressManager}.
/// @custom:security-contact security@taiko.xyz
contract MainnetSharedAddressManager is AddressManager {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        if (_chainId == 1) {
            if (_name == LibStrings.B_TAIKO_TOKEN) {
                return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
            }
            if (_name == LibStrings.B_QUOTA_MANAGER) {
                return 0x91f67118DD47d502B1f0C354D0611997B022f29E;
            }
            if (_name == LibStrings.B_BRIDGE) {
                return 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
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
        } else if (_chainId == 167_000) {
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

        return super._getAddress(_chainId, _name);
    }
}
