// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../L1/tiers/ITierProvider.sol";
import "./IVerifier.sol";

/// @title GuardianVerifier
/// @custom:security-contact security@taiko.xyz
contract GuardianVerifier is EssentialContract, IVerifier {
    uint256[50] private __gap;

    error GV_INVALID_PROOF();
    error GV_PERMISSION_DENIED();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata,
        TaikoData.TierProof calldata _proof
    )
        external
        view
    {
        if (_proof.tier != LibTiers.TIER_GUARDIAN) {
            revert GV_INVALID_PROOF();
        }

        if (_ctx.msgSender != resolve(LibStrings.B_GUARDIAN_PROVER, false)) {
            revert GV_PERMISSION_DENIED();
        }
    }
}
