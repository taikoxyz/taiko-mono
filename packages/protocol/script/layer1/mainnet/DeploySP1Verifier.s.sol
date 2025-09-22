// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@sp1-contracts/src/v5.0.0/SP1VerifierPlonk.sol";
import "src/layer1/verifiers/TaikoSP1Verifier.sol";
import "src/shared/libs/LibNetwork.sol";
import "script/BaseScript.sol";

contract DeploySP1Verifier is BaseScript {
    function run() external broadcast {
        checkResolverOwnership();

        address sp1RemoteVerifier = address(new SP1RemoteVerifier());
        // Deploy sp1 plonk verifier
        DefaultResolver(resolver).registerAddress(
            block.chainid, "sp1_remote_verifier", sp1RemoteVerifier
        );

        deploy({
            name: "tier_zkvm_sp1",
            impl: address(new SP1Verifier(LibNetwork.TAIKO_MAINNET, sp1RemoteVerifier)),
            data: abi.encodeCall(SP1Verifier.init, (address(0)))
        });
    }
}
