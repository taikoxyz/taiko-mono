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

contract TaikoTimelockController is EssentialContract, TimelockControllerUpgradeable {
    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param minDelay The minimal delay.
    function init(
        address _owner,
        uint256 minDelay
    )
        external
        initializer
        initEssential(_owner, address(0))
    {
        address[] memory nil = new address[](0);
        __TimelockController_init(minDelay, nil, nil, owner());
    }

    /// @dev Allows the admin to get around of the min delay.
    function getMinDelay() public view override returns (uint256) {
        return hasRole(TIMELOCK_ADMIN_ROLE, msg.sender) ? 0 : super.getMinDelay();
    }
}
