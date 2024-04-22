// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Test.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../contracts/tokenvault/ERC20Vault.sol";
import "../contracts/tokenvault/ERC721Vault.sol";
import "../contracts/tokenvault/ERC1155Vault.sol";

import "../contracts/L1/TaikoToken.sol";
import "../contracts/L1/TaikoL1.sol";
import "../contracts/verifiers/SgxVerifier.sol";
import "../contracts/verifiers/RiscZeroVerifier.sol";
import "../contracts/L1/tiers/TierProviderV1.sol";
import "../contracts/L1/hooks/AssignmentHook.sol";
import "../contracts/L1/provers/GuardianProver.sol";

import "../contracts/L2/DelegateOwner.sol";

import "../contracts/team/TimelockTokenPool.sol";
import "../contracts/team/airdrop/ERC20Airdrop.sol";
import "../contracts/team/airdrop/ERC20Airdrop2.sol";
import "../contracts/team/airdrop/ERC721Airdrop.sol";

import "../test/common/erc20/FreeMintERC20.sol";
import "../test/L2/TaikoL2EIP1559Configurable.sol";

import "./DeployCapability.sol";
import "./HelperContracts.sol";
import "./L2/LibL2Signer.sol";

abstract contract TaikoTest is Test, DeployCapability {
    uint256 private _seed = 0x12345678;
    address internal Alice = vm.addr(0x1);
    address internal Bob = vm.addr(0x2);
    address internal Carol = vm.addr(0x3);
    address internal David = randAddress();
    address internal Emma = randAddress();
    address internal Frank = randAddress();
    address internal Grace = randAddress();
    address internal Henry = randAddress();
    address internal Isabella = randAddress();
    address internal James = randAddress();
    address internal Katherine = randAddress();
    address internal Liam = randAddress();
    address internal Mia = randAddress();
    address internal Noah = randAddress();
    address internal Olivia = randAddress();
    address internal Patrick = randAddress();
    address internal Quinn = randAddress();
    address internal Rachel = randAddress();
    address internal Samuel = randAddress();
    address internal Taylor = randAddress();
    address internal Ulysses = randAddress();
    address internal Victoria = randAddress();
    address internal William = randAddress();
    address internal Xavier = randAddress();
    address internal Yasmine = randAddress();
    address internal Zachary = randAddress();

    function randAddress() internal returns (address) {
        bytes32 randomHash = keccak256(abi.encodePacked("address", _seed++));
        return address(bytes20(randomHash));
    }

    function randBytes32() internal returns (bytes32) {
        return keccak256(abi.encodePacked("bytes32", _seed++));
    }

    function strToBytes32(string memory input) internal pure returns (bytes32 result) {
        require(bytes(input).length <= 32, "String too long");
        // Copy the string's bytes directly into the bytes32 variable
        assembly {
            result := mload(add(input, 32))
        }
    }
}
