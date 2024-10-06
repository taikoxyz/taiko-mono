// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/common/EssentialContract.sol";
import "../iface/ILookahead.sol";

/// @title PreconfTaskManager.sol
/// @custom:security-contact security@taiko.xyz
contract Lookahead is ILookahead, EssentialContract {
    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    function isCurrentPreconfer(address addr) external view returns (bool) {
        return true;
    }
}
