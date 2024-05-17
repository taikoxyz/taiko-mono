// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ContextUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

/// @title MerkleWhitelist
/// @dev Merkle Tree Whitelist
/// @custom:security-contact security@taiko.xyz
contract MerkleWhitelist is ContextUpgradeable, UUPSUpgradeable, Ownable2StepUpgradeable {
    event RootUpdated(bytes32 _root);
    event MintConsumed(address _minter, uint256 _mintAmount);
    event BlacklistUpdated(address _blacklist);

    error MINTS_EXCEEDED();
    error INVALID_PROOF();
    error INVALID_TOKEN_AMOUNT();
    error ADDRESS_BLACKLISTED();

    /// @notice Merkle Tree Root
    bytes32 public root;
    /// @notice Tracker for minted leaves
    mapping(bytes32 leaf => bool hasMinted) public minted;
    /// @notice Blackist address
    IMinimalBlacklist public blacklist;
    /// @notice Gap for upgrade safety
    uint256[47] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Update the blacklist address
    /// @param _blacklist The new blacklist address
    function updateBlacklist(IMinimalBlacklist _blacklist) external onlyOwner {
        blacklist = _blacklist;
        emit BlacklistUpdated(address(_blacklist));
    }

    /// @notice Contract initializer
    /// @param _root Merkle Tree root
    function initialize(
        address _owner,
        bytes32 _root,
        IMinimalBlacklist _blacklist
    )
        external
        initializer
    {
        __MerkleWhitelist_init(_owner, _root, _blacklist);
    }

    /// @notice Check if a wallet can free mint
    /// @param _minter Address of the minter
    /// @param _maxMints Max amount of free mints
    /// @return Whether the wallet can mint
    function canMint(address _minter, uint256 _maxMints) public view returns (bool) {
        if (blacklist.isBlacklisted(_minter)) revert ADDRESS_BLACKLISTED();
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
    function __MerkleWhitelist_init(
        address _owner,
        bytes32 _root,
        IMinimalBlacklist _blacklist
    )
        internal
        initializer
    {
        _transferOwnership(_owner == address(0) ? msg.sender : _owner);
        __Context_init();
        root = _root;
        blacklist = _blacklist;
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

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
