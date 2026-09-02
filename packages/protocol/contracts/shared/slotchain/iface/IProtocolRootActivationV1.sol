// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Protocol root component activation interface
/// @custom:security-contact security@taiko.xyz
interface IProtocolRootActivationV1 {
    /// @notice Returns the immutable root-factory binding and local activation state.
    /// @return magic_ The PRA1 response magic.
    /// @return protocolRootFactory_ The sole factory allowed to activate this component.
    /// @return campaignKey_ The root campaign that deployed this component.
    /// @return state_ The activation state, where zero is inactive and one is active.
    function protocolRootActivationV1()
        external
        view
        returns (bytes4 magic_, address protocolRootFactory_, bytes32 campaignKey_, uint8 state_);

    /// @notice Permanently activates this component for its deployment campaign.
    /// @param _campaignKey The exact constructor-bound campaign key.
    /// @return magic_ The RAA1 activation acknowledgement.
    function activateProtocolRootV1(bytes32 _campaignKey) external returns (bytes4 magic_);
}
