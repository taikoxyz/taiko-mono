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

import "../tiers/ITierProvider.sol";
import "../ITaikoL1.sol";
import "./Guardians.sol";

/// @title GuardianProver
/// @custom:security-contact security@taiko.xyz
contract GuardianProver is Guardians {
    uint256[50] private __gap;

    event GuardianApproval(
        address indexed addr, uint256 indexed blockId, bytes32 blockHash, bool approved
    );

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    /// @dev Called by guardians to approve a guardian proof
    /// @param _meta The block's metadata.
    /// @param _tran The valid transition.
    /// @param _proof The tier proof.
    /// @return approved_ If the minimum number of participants sent the same proof, and proving
    /// transaction is fired away returns true, false otherwise.
    function approve(
        TaikoData.BlockMetadata calldata _meta,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
        whenNotPaused
        nonReentrant
        returns (bool approved_)
    {
        if (_proof.tier != LibTiers.TIER_GUARDIAN) revert INVALID_PROOF();
        bytes32 hash = keccak256(abi.encode(_meta, _tran));
        approved_ = approve(_meta.id, hash);

        if (approved_) {
            deleteApproval(hash);
            ITaikoL1(resolve("taiko", false)).proveBlock(_meta.id, abi.encode(_meta, _tran, _proof));
        }

        emit GuardianApproval(msg.sender, _meta.id, _tran.blockHash, approved_);
    }
}
