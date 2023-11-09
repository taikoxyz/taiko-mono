// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { OwnableUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { MerkleProofUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/MerkleProofUpgradeable.sol";

import { Proxied } from "../../common/Proxied.sol";

/// @title MerkleClaimable
/// Contract for managing Taiko token airdrop for eligible users
// TODO(dani): add claimStart and claimEnd timestamp so claim() can only be
// called between these two timestamps.
// Better to add non-reentrance guard to claim().

abstract contract MerkleClaimable is OwnableUpgradeable {
    mapping(bytes32 => bool) public isClaimed;
    bytes32 public merkleRoot;
    uint128 claimStart;
    uint128 claimEnd;

    event Claimed(bytes32 hash);

    error CLAIM_NOT_ONGOING();
    error CLAIMED_ALREADY();
    error INVALID_PROOF();
    error INVALID_MERKLE_ROOT();

    modifier ongoingClaim() {
        if (
            merkleRoot == 0x0 || claimStart == 0 || claimEnd == 0
                || claimStart > block.timestamp || claimEnd < block.timestamp
        ) revert CLAIM_NOT_ONGOING();
        _;
    }

    function claim(
        bytes calldata data,
        bytes32[] calldata proof
    )
        external
        ongoingClaim
    {
        (address user, uint256 amount) = abi.decode(data, (address, uint256));

        bytes32 hash =
            keccak256(abi.encode("CLAIM_TAIKO_AIRDROP", user, amount));

        if (isClaimed[hash]) revert CLAIMED_ALREADY();

        if (!MerkleProofUpgradeable.verify(proof, merkleRoot, hash)) {
            revert INVALID_PROOF();
        }

        isClaimed[hash] = true;
        _claimWithData(data);
        emit Claimed(hash);
    }

    /// @notice Set time window for claiming
    /// @param _claimStart Unix timestamp for claim start
    /// @param _claimEnd Unix timestamp for claim end
    function setClaimWindow(
        uint128 _claimStart,
        uint128 _claimEnd
    )
        external
        onlyOwner
    {
        claimStart = _claimStart;
        claimEnd = _claimEnd;
    }

    function _init(bytes32 _merkleRoot) internal {
        OwnableUpgradeable.__Ownable_init();

        if (_merkleRoot == 0x0) {
            revert INVALID_MERKLE_ROOT();
        }
        merkleRoot = _merkleRoot;
    }

    /// @dev Must revert in case of errors.
    function _claimWithData(bytes calldata data) internal virtual;
}
