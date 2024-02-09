// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import { MerkleProofUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/MerkleProofUpgradeable.sol";
import "../../common/EssentialContract.sol";

interface Delegation {
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

/// @title MerkleClaimable
/// Contract for managing Taiko token airdrop for eligible users
abstract contract MerkleClaimable is EssentialContract {
    mapping(bytes32 => bool) public isClaimed;
    bytes32 public merkleRoot;
    uint64 public claimStart;
    uint64 public claimEnd;

    uint256[47] private __gap;

    event Claimed(bytes32 hash);

    error CLAIM_NOT_ONGOING();
    error CLAIMED_ALREADY();
    error INVALID_PROOF();

    modifier ongoingClaim() {
        if (
            merkleRoot == 0x0 || claimStart == 0 || claimEnd == 0 || claimStart > block.timestamp
                || claimEnd < block.timestamp
        ) revert CLAIM_NOT_ONGOING();
        _;
    }

    function claim(
        bytes calldata data,
        bytes32[] calldata proof,
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        nonReentrant
        ongoingClaim
    {
        bytes32 hash = keccak256(abi.encode("CLAIM_TAIKO_AIRDROP", data));

        if (isClaimed[hash]) revert CLAIMED_ALREADY();

        if (!MerkleProofUpgradeable.verify(proof, merkleRoot, hash)) {
            revert INVALID_PROOF();
        }

        isClaimed[hash] = true;
        _claimWithData(
            data, 
            delegatee, 
            nonce,
            expiry,
            v,
            r,
            s
        );
        emit Claimed(hash);
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

    function _setConfig(uint64 _claimStart, uint64 _claimEnd, bytes32 _merkleRoot) internal {
        claimStart = _claimStart;
        claimEnd = _claimEnd;
        merkleRoot = _merkleRoot;
    }

    /// @dev Must revert in case of errors.
    function _claimWithData(
        bytes calldata data, 
        address delegate,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal virtual;
}
