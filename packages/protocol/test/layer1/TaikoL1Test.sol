// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/TaikoL1.sol";
import "src/layer1/token/TaikoToken.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/provers/GuardianProver.sol";
import "src/layer1/team/airdrop/ERC20Airdrop.sol";
import "src/shared/bridge/QuotaManager.sol";
import "../layer1/based/TestTierProvider.sol";
import "../shared/TaikoTest.sol";

abstract contract TaikoL1Test is TaikoTest { }
