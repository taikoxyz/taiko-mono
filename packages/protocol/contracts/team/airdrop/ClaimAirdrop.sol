// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { OwnableUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { MerkleProofUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/MerkleProofUpgradeable.sol";
import { SafeERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { Proxied } from "../../common/Proxied.sol";

/// @title ClaimAirdrop
/// Contract for managing Taiko token airdrop for eligible users
contract ClaimAirdrop is OwnableUpgradeable {
    using SafeERC20Upgradeable for ERC20Upgradeable;

    mapping(bytes32 => bool) private leafClaimed;
    address public tkoAddress;
    bytes32 public merkleRoot = 0x0;

    event UserClaimed(address indexed user, uint256 amount);

    error CLAIM_NOT_STARTED();
    error CLAIMED_ALREADY();
    error INCORRECT_PROOF();
    error REENTRANT_CALL();

    /// @notice Initializes the owner for the upgradable contract
    /// @param _tkoAddress Address of the TKO contract
    function init(address _tkoAddress) external initializer {
        OwnableUpgradeable.__Ownable_init();
        tkoAddress = _tkoAddress;
    }

    /// @notice Claim airdrop allowance via airdrop list
    /// @param merkleProof Merkle proof for verifcation
    /// @param allowance Allowance assigned to msg.sender (coming from DB -> UI
    /// -> User)
    function claimAllowance(
        bytes32[] calldata merkleProof,
        uint256 allowance
    )
        external
    {
        if (merkleRoot == 0x0) {
            revert CLAIM_NOT_STARTED();
        }

        // Merkle proof verification
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, allowance));
        if (!MerkleProofUpgradeable.verify(merkleProof, merkleRoot, leaf)) {
            revert INCORRECT_PROOF();
        }

        if (!leafClaimed[leaf]) {
            leafClaimed[leaf] = true;
            ERC20Upgradeable(tkoAddress).safeTransfer(msg.sender, allowance);

            emit UserClaimed(msg.sender, allowance);
            return;
        }
        revert CLAIMED_ALREADY();
    }

    /// @notice Set new Merkle Root
    /// @param _merkleRoot Root of merkle tree
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    /// @notice Withdraw funds from contract - when claim window expired
    /// @param withdrawTo The address tokens should be withdrawn to
    function withdraw(address withdrawTo) external payable onlyOwner {
        uint256 leftOver = ERC20Upgradeable(tkoAddress).balanceOf(address(this));
        ERC20Upgradeable(tkoAddress).safeTransfer(withdrawTo, leftOver);
    }
}

/// @title ProxiedClaimAirdrop
/// @notice Proxied version of the parent contract.
contract ProxiedClaimAirdrop is Proxied, ClaimAirdrop { }
