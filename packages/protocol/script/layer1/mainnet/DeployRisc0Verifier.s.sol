// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import "src/layer1/verifiers/TaikoRisc0Verifier.sol";
import "src/shared/libs/LibNetwork.sol";
import "script/BaseScript.sol";

contract DeployRisc0Verifier is BaseScript {
    function run() external broadcast {
        checkResolverOwnership();

        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);

        DefaultResolver(resolver).registerAddress(
            block.chainid, "risc0_groth16_verifier", address(verifier)
        );

        deploy({
            name: "tier_zkvm_risc0",
            impl: address(new TaikoRisc0Verifier(LibNetwork.TAIKO_MAINNET, address(verifier))),
            data: abi.encodeCall(TaikoRisc0Verifier.init, (address(0)))
        });
    }
}
