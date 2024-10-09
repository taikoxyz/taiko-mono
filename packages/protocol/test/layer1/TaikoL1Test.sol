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
import "src/shared/tokenvault/BridgedERC20V2.sol";
import "src/shared/tokenvault/BridgedERC721.sol";
import "src/shared/tokenvault/BridgedERC1155.sol";
import "src/shared/tokenvault/ERC20Vault.sol";
import "src/shared/tokenvault/ERC721Vault.sol";
import "src/shared/tokenvault/ERC1155Vault.sol";
import "test/shared/token/FreeMintERC20.sol";
import "test/shared/token/RegularERC20.sol";
import "test/shared/token/MayFailFreeMintERC20.sol";
import "test/layer1/based/TestTierProvider.sol";
import "test/shared/TaikoTest.sol";

abstract contract TaikoL1Test is TaikoTest { }
