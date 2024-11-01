// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/LibStrings.sol";
import "src/shared/common/LibNetwork.sol";
import "./AddressCache.sol";

/// @title RollupAddressCache
/// @custom:security-contact security@taiko.xyz
contract RollupAddressCache is AddressCache {
    function getCachedAddress(
        uint64 _chainId,
        bytes32 _name
    )
        internal
        pure
        override
        returns (bool found, address addr)
    {
        if (_chainId != LibNetwork.ETHEREUM_MAINNET) {
            return (false, address(0));
        }

        if (_name == LibStrings.B_TAIKO_TOKEN) {
            return (true, 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800);
        }
        if (_name == LibStrings.B_SIGNAL_SERVICE) {
            return (true, 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C);
        }
        if (_name == LibStrings.B_BRIDGE) {
            return (true, 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC);
        }
        if (_name == LibStrings.B_TAIKO) {
            return (true, 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a);
        }
        if (_name == LibStrings.B_TIER_ROUTER) {
            return (true, 0x2Ae89453c6c79Add793db7B9d23c275b90C26065);
        }
        if (_name == LibStrings.B_TIER_SGX) {
            return (true, 0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81);
        }
        if (_name == LibStrings.B_TIER_GUARDIAN_MINORITY) {
            return (true, 0x579A8d63a2Db646284CBFE31FE5082c9989E985c);
        }
        if (_name == LibStrings.B_TIER_GUARDIAN) {
            return (true, 0xE3D777143Ea25A6E031d1e921F396750885f43aC);
        }
        if (_name == LibStrings.B_AUTOMATA_DCAP_ATTESTATION) {
            return (true, 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3);
        }
        if (_name == LibStrings.B_PRECONF_REGISTRY) {
            return (true, address(0));
        }
        if (_name == LibStrings.B_CHAIN_WATCHDOG) {
            return (true, 0xE3D777143Ea25A6E031d1e921F396750885f43aC);
        }
        return (false, address(0));
    }
}
