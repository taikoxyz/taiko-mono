// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibStrings.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/common/ResolverBase.sol";

/// @title RollupResolver
/// @dev Resolver used by Taiko mainnet protocol on Ethereum.
/// @custom:security-contact security@taiko.xyz
contract RollupResolver is ResolverBase {
    function getAddress(uint256 _chainId, bytes32 _name) internal pure override returns (address) {
        if (_chainId != LibNetwork.ETHEREUM_MAINNET) {
            return address(0);
        }
        if (_name == LibStrings.B_BOND_TOKEN) {
            return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
        }
        if (_name == LibStrings.B_TAIKO_TOKEN) {
            return 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
        }
        if (_name == LibStrings.B_SIGNAL_SERVICE) {
            return 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C;
        }
        if (_name == LibStrings.B_BRIDGE) {
            return 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
        }
        if (_name == LibStrings.B_TAIKO) {
            return 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
        }

        if (_name == LibStrings.B_AUTOMATA_DCAP_ATTESTATION) {
            return 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;
        }
        if (_name == LibStrings.B_PROOF_VERIFIER) {
            return 0xB16931e78d0cE3c9298bbEEf3b5e2276D34b8da1;
        }
        return address(0);
    }
}
