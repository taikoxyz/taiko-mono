// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../shared/TaikoTest.sol";

import "../../contracts/layer1/token/TaikoToken.sol";
import "../../contracts/layer1/TaikoL1.sol";
import "../../contracts/layer1/verifiers/SgxVerifier.sol";
import "../../contracts/layer1/verifiers/SP1Verifier.sol";
import "../../contracts/layer1/verifiers/Risc0Verifier.sol";
import "../../contracts/layer1/provers/GuardianProver.sol";
import "../../contracts/layer1/team/airdrop/ERC20Airdrop.sol";
import "../../contracts/shared/bridge/QuotaManager.sol";

import "../layer1/core/TestTierProvider.sol";

abstract contract TaikoL1Test is TaikoTest { }
