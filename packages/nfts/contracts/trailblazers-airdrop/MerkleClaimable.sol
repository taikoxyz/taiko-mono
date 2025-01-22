// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ContextUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/// @title MerkleClaimable
/// @notice Contract for managing Taiko token airdrop for eligible users
/// @custom:security-contact security@taiko.xyz
abstract contract MerkleClaimable is
    ContextUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable
{
    /// @notice Mapping of hashes and their claim status
    mapping(bytes32 hash => bool claimed) public isClaimed;

    /// @notice Merkle root of the tree
    bytes32 public merkleRoot;

    /// @notice Unix timestamp for claim start
    uint64 public claimStart;

    /// @notice Unix timestamp for claim end
    uint64 public claimEnd;

    uint256[47] private __gap;

    /// @notice Event emitted when a claim is made
    /// @param hash Hash of the claim
    event Claimed(bytes32 hash);

    /// @notice Event emitted when config is changed
    /// @param claimStart Unix timestamp for claim start
    /// @param claimEnd Unix timestamp for claim end
    /// @param merkleRoot Merkle root of the tree
    event ConfigChanged(uint64 claimStart, uint64 claimEnd, bytes32 merkleRoot);

    /// @notice Errors
    error CLAIM_NOT_ONGOING();
    error CLAIMED_ALREADY();
    error INVALID_PARAMS();
    error INVALID_PROOF();

    /// @notice Modifier to check if the claim is ongoing
    modifier ongoingClaim() {
        if (
            merkleRoot == 0x0 || claimStart == 0 || claimEnd == 0 || claimStart > block.timestamp
                || claimEnd < block.timestamp
        ) revert CLAIM_NOT_ONGOING();
        _;
    }

    /// @notice Set config parameters
    /// @param _claimStart Unix timestamp for claim start
    /// @param _claimEnd Unix timestamp for claim end
    /// @param _merkleRoot Merkle root of the tree
    function setConfig(
        uint64 _claimStart,
        uint64 _claimEnd,
        bytes32 _merkleRoot
    )
        external
        onlyOwner
    {
        _setConfig(_claimStart, _claimEnd, _merkleRoot);
    }

    /// @notice Initialize the contract
    /// @param _claimStart Unix timestamp for claim start
    /// @param _claimEnd Unix timestamp for claim end
    /// @param _merkleRoot Merkle root of the tree
    function __MerkleClaimable_init(
        uint64 _claimStart,
        uint64 _claimEnd,
        bytes32 _merkleRoot
    )
        internal
        onlyInitializing
    {
        __Context_init();
        _setConfig(_claimStart, _claimEnd, _merkleRoot);
    }

    /// @notice Verify an airdrop claim
    /// @param data Data to be hashed
    /// @param proof Merkle proof
    function _verifyClaim(bytes memory data, bytes32[] calldata proof) internal ongoingClaim {
        bytes32 hash = keccak256(abi.encode("CLAIM_TAIKO_AIRDROP", data));

        if (isClaimed[hash]) revert CLAIMED_ALREADY();
        if (!_verifyMerkleProof(proof, merkleRoot, hash)) revert INVALID_PROOF();

        isClaimed[hash] = true;
        emit Claimed(hash);
    }

    /// @notice Verify a Merkle proof
    /// @param _proof Merkle proof
    /// @param _merkleRoot Merkle root
    /// @param _value Value to verify
    /// @return Whether the proof is valid
    function _verifyMerkleProof(
        bytes32[] calldata _proof,
        bytes32 _merkleRoot,
        bytes32 _value
    )
        internal
        pure
        virtual
        returns (bool)
    {
        return MerkleProof.verify(_proof, _merkleRoot, _value);
    }

    /// @notice Set config parameters
    /// @param _claimStart Unix timestamp for claim start
    /// @param _claimEnd Unix timestamp for claim end
    /// @param _merkleRoot Merkle root of the tree
    function _setConfig(uint64 _claimStart, uint64 _claimEnd, bytes32 _merkleRoot) private {
        if (_claimStart > _claimEnd) revert INVALID_PARAMS();

        claimStart = _claimStart;
        claimEnd = _claimEnd;
        merkleRoot = _merkleRoot;
        emit ConfigChanged(_claimStart, _claimEnd, _merkleRoot);
    }

    /// @notice Check if a claim has been made
    /// @param user Address of the user
    /// @param amount Amount of tokens claimed
    /// @return Whether the claim has been made
    function hasClaimed(address user, uint256 amount) external view returns (bool) {
        bytes32 hash = keccak256(abi.encode("CLAIM_TAIKO_AIRDROP", (abi.encode(user, amount))));
        return isClaimed[hash];
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
