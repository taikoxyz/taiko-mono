// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { LibAddress } from "../libs/LibAddress.sol";
import { Proxied } from "../common/Proxied.sol";
import { TaikoData } from "./TaikoData.sol";

/// @title AssignmentValidator Interface
contract AssignmentValidator is EssentialContract {
    using ECDSA for bytes32;
    using LibAddress for address;

    error ASSIGNMENT_EXPIRED();
    error INVALID_SIGNATURE();
    error INVALID_PARAMS();
    error INSUFFICIENT_TX_VALUE();
    error TIER_NOT_FUND();

    /// @notice Initializes the rollup.
    /// @param _addressManager The {AddressManager} address.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Assigns a prover to a specific block or reverts if this prover
    /// is not available.
    /// @param proposer The proposer address
    /// @param minTier The ID of minimal tier for this block
    /// @param txListHash The block's txList hash
    /// @param assignment The assignment to evaluate
    /// @return prover The assigned prover
    /// @return fee The prover fee for the min tier.
    function validateAssignment(
        address proposer,
        uint16 minTier,
        bytes32 txListHash,
        TaikoData.ProverAssignment calldata assignment
    )
        external
        payable
        onlyFromNamed("taiko")
        returns (address prover, uint256 fee)
    {
        // Checl txList not zero
        if (txListHash == 0 || proposer == address(0)) revert INVALID_PARAMS();

        // Check assignment not expired
        if (block.timestamp >= assignment.expiry) revert ASSIGNMENT_EXPIRED();

        // Recover the prover address
        prover = keccak256(
            abi.encode(
                "PROVER_ASSIGNMENT",
                txListHash,
                assignment.feeToken,
                assignment.expiry,
                assignment.tierFees
            )
        ).recover(assignment.signature);

        // The prover address cannot be zero
        if (prover == address(0)) revert INVALID_SIGNATURE();

        // Find the fee for the min tier
        fee = _findFee(assignment.tierFees, minTier);

        if (assignment.feeToken == address(0)) {
            // feeToken is Ether
            if (msg.value < fee) revert INSUFFICIENT_TX_VALUE();
            prover.sendEther(fee);
            unchecked {
                // Return the extra Ether to the proposer
                uint256 refund = msg.value - fee;
                if (refund != 0) proposer.sendEther(refund);
            }
        } else {
            // ERC20 token as fee. We send back Ether if msg.value is nonzero.
            if (msg.value != 0) proposer.sendEther(msg.value);
            ERC20(assignment.feeToken).transferFrom(proposer, prover, fee);
        }
    }

    function _findFee(
        TaikoData.TierFee[] calldata tierFees,
        uint16 tierId
    )
        private
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < tierFees.length; ++i) {
            if (tierFees[i].tier == tierId) {
                return tierFees[i].fee;
            }
        }
        revert TIER_NOT_FUND();
    }
}

/// @title ProxiedAssignmentValidator
/// @notice Proxied version of the parent contract.
contract ProxiedAssignmentValidator is Proxied, AssignmentValidator { }
