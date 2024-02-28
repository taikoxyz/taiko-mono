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

import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "../../common/EssentialContract.sol";

/// @title TaikoTimelockController
/// @custom:security-contact security@taiko.xyz
contract TaikoTimelockController is EssentialContract, TimelockControllerUpgradeable {
    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _minDelay The minimal delay.
    function init(address _owner, uint256 _minDelay) external initializer {
        __Essential_init(_owner);
        address[] memory nil = new address[](0);
        __TimelockController_init(_minDelay, nil, nil, owner());
    }

    /// @dev Gets the minimum delay for an operation to become valid, allows the admin to get around
    /// of the min delay.
    /// @return The minimum delay.
    function getMinDelay() public view override returns (uint256) {
        return hasRole(TIMELOCK_ADMIN_ROLE, msg.sender) ? 0 : super.getMinDelay();
    }
}
