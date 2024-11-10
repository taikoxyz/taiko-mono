// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SP1Verifier as RemoteSP1Verifier } from "@sp1-contracts/src/v3.0.0/SP1VerifierPlonk.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "script/BaseScript.sol";

contract DeploySP1Verifier is BaseScript {
    function run() external broadcast {
        checkResolverOwnership();
        // Deploy sp1 plonk verifier
        RemoteSP1Verifier succinctVerifier = new RemoteSP1Verifier();
        DefaultResolver(resolver).registerAddress(
            block.chainid, "sp1_remote_verifier", address(succinctVerifier)
        );

        deploy({
            name: "tier_zkvm_sp1",
            impl: address(new SP1Verifier()),
            data: abi.encodeCall(SP1Verifier.init, (address(0), resolver))
        });
    }
}
