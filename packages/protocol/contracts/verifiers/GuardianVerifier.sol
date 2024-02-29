// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../L1/TaikoData.sol";
import "./IVerifier.sol";

/// @title GuardianVerifier
/// @custom:security-contact security@taiko.xyz
contract GuardianVerifier is EssentialContract, IVerifier {
    uint256[50] private __gap;

    error PERMISSION_DENIED();

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
        TaikoData.TierProof calldata
    )
        external
        view
    {
        if (_ctx.msgSender != resolve("guardian_prover", false)) {
            revert PERMISSION_DENIED();
        }
    }
}
