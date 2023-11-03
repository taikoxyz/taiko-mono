// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { OwnableUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { MerkleProofUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/MerkleProofUpgradeable.sol";

import { Proxied } from "../../common/Proxied.sol";

/// @title BaseAirdrop
/// Contract for managing Taiko token airdrop for eligible users
abstract contract BaseAirdrop is OwnableUpgradeable {
    mapping(bytes32 => bool) public leafClaimed;
    address public tokenVaultAddress; // Vault
    address public tokenAddress; // Token
    bytes32 public merkleRoot = 0x0;

    error CLAIM_NOT_STARTED();
    error CLAIMED_ALREADY();
    error INCORRECT_PROOF();
    error REENTRANT_CALL();
    error UNSUCCESSFUL_TRANSFER();

    /// @notice Initializes the owner for the upgradable contract
    /// @param _tokenVaultAddress Address of the TKO/NFT vault contracts
    /// @param _tokenAddress Address of the TKO/NFT
    /// @param _merkleRoot Merkle root (if know at init time, can be 0x0)
    function init(
        address _tokenVaultAddress,
        address _tokenAddress,
        bytes32 _merkleRoot
    )
        external
        initializer
    {
        OwnableUpgradeable.__Ownable_init();
        tokenVaultAddress = _tokenVaultAddress;
        tokenAddress = _tokenAddress;
        merkleRoot = _merkleRoot;
    }

    /// @notice Claim airdrop
    /// @param data Encoded data containing merkle proof and related variables
    /// (amount, contract, etc.)
    function claim(bytes calldata data) external virtual;

    /// @notice Verifying a proof during claiming
    /// @param merkleProof Merkle proof for verifcation
    /// @param leaf Leaf within the merkle tree
    function verifyProof(
        bytes32[] memory merkleProof,
        bytes32 leaf
    )
        internal
        view
    {
        if (!MerkleProofUpgradeable.verify(merkleProof, merkleRoot, leaf)) {
            revert INCORRECT_PROOF();
        }
    }

    /// @notice Set new Merkle Root
    /// @param _merkleRoot Root of merkle tree
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }
}
