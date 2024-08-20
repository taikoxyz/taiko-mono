// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/LibStrings.sol";
import "../libs/LibNetwork.sol";

/// @title LibRollupAddressCache
/// @custom:security-contact security@taiko.xyz
library LibRollupAddressCache {
    function getAddress(
        uint64 _chainId,
        bytes32 _name
    )
        internal
        pure
        returns (bool found, address addr)
    {
        if (_chainId == LibNetwork.ETHEREUM_MAINNET) {
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
                return (true, 0x6E997f1F22C40ba37F633B08f3b07E10Ed43155a);
            }
            if (_name == LibStrings.B_VERIFIER_TEE_SGX) {
                return (true, 0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81);
            }
            if (_name == LibStrings.B_VERIFIER_ZK_RISC0) {
                return (false, address(0));
            }
            if (_name == LibStrings.B_VERIFIER_ZK_SP1) {
                return (false, address(0));
            }
            if (_name == LibStrings.B_VERIFIER_GUARDIAN_MINORITY) {
                return (true, 0x579A8d63a2Db646284CBFE31FE5082c9989E985c);
            }
            if (_name == LibStrings.B_VERIFIER_GUARDIAN) {
                return (true, 0xE3D777143Ea25A6E031d1e921F396750885f43aC);
            }
            if (_name == LibStrings.B_AUTOMATA_DCAP_ATTESTATION) {
                return (true, 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3);
            }
            if (_name == LibStrings.B_PROPOSER_ACCESS) {
                return (true, address(0));
            }
            if (_name == LibStrings.B_CHAIN_WATCHDOG) {
                return (true, address(0));
            }
        }
        return (false, address(0));
    }
}
