// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/// @title MerkleWhitelist
/// @dev Merkle Tree Whitelist
/// @custom:security-contact security@taiko.xyz
contract MerkleWhitelist is ContextUpgradeable {
    event RootUpdated(bytes32 _root);
    event MintConsumed(address _minter, uint256 _mintAmount);

    error MINTS_EXCEEDED();
    error INVALID_PROOF();
    error INVALID_TOKEN_AMOUNT();

    /// @notice Merkle Tree Root
    bytes32 public root;
    /// @notice Tracker for minted leaves
    mapping(bytes32 => bool) public minted;

    uint256[48] private __gap;

    /// @notice Contract initializer
    /// @param _root Merkle Tree root
    function initialize(bytes32 _root) external initializer {
        __Context_init();
        root = _root;
    }

    /// @notice Check if a wallet can free mint
    /// @param _minter Address of the minter
    /// @param _maxMints Max amount of free mints
    /// @return Whether the wallet can mint
    function canMint(address _minter, uint256 _maxMints) public view returns (bool) {
        bytes32 _leaf = leaf(_minter, _maxMints);
        return !minted[_leaf];
    }

    /// @notice Generate a leaf from the minter and mint counts
    /// @param _minter Address of the minter
    /// @param _maxMints Max amount of free mints
    /// @return The leaf hash
    function leaf(address _minter, uint256 _maxMints) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(_minter, _maxMints))));
    }

    /// @notice Internal initializer
    /// @param _root Merkle Tree root
    function __MerkleWhitelist_init(bytes32 _root) internal initializer {
        __Context_init();
        root = _root;
    }

    /// @notice Update the merkle tree's root
    /// @param _root The new root
    function _updateRoot(bytes32 _root) internal {
        root = _root;
        emit RootUpdated(_root);
    }

    /// @notice Permanently consume mints from the minter
    /// @param _proof Merkle proof
    /// @param _maxMints Max amount of free mints
    function _consumeMint(bytes32[] calldata _proof, uint256 _maxMints) internal {
        if (!canMint(_msgSender(), _maxMints)) revert MINTS_EXCEEDED();
        bytes32 _leaf = leaf(_msgSender(), _maxMints);
        if (!MerkleProof.verify(_proof, root, _leaf)) revert INVALID_PROOF();
        minted[_leaf] = true;
        emit MintConsumed(_msgSender(), _maxMints);
    }
}
