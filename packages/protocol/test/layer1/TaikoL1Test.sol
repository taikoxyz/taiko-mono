// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoL1.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/provers/GuardianProver.sol";
import "src/layer1/tiers/LibTiers.sol";
import "src/layer1/team/airdrop/ERC20Airdrop.sol";
import "src/shared/bridge/QuotaManager.sol";
import "test/shared/TaikoTest.sol";

abstract contract TaikoL1Test is TaikoTest {


    function deployTaikoL1(address impl) internal returns (TaikoL1) {
     return   TaikoL1(
            deploy({
                name: "taiko",
                impl: impl,
                data: ""
            })
        );
    }

    function deployGuardianProver() internal returns (GuardianProver) {
     return   GuardianProver(
            deploy({
                name: "guardian_prover",
                impl: address(new GuardianProver()),
                data: abi.encodeCall(GuardianProver.init, (address(0), address(resolver)))
            })
        );
    }

    function deploySgxVerifier() internal returns (SgxVerifier) {
        return SgxVerifier(
            deploy({
                name: "tier_sgx",
                impl: address(new SgxVerifier()),
                data: abi.encodeCall(SgxVerifier.init, (address(0), address(resolver)))
            })
        );
    } }
