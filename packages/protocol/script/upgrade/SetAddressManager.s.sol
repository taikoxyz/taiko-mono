// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "./UpgradeScript.s.sol";

interface IEssentialContract {
    function setAddressManager(address newAddressManager) external;
}
/// @notice Each contract (which inherits EssentialContract) is having a
/// setAddressManager() setter. In such case AddressManager needs to get
/// changed, we need a quick way to update it.
///
/// Invokaction example:
/// forge script SetAddressManager --sig "run(address,address)"  <address>
/// <address>

contract SetAddressManager is UpgradeScript {
    function run(
        address essentialContract,
        address newAddressManager
    )
        external
        setUp
    {
        IEssentialContract(essentialContract).setAddressManager(
            newAddressManager
        );
        console2.log(
            essentialContract,
            " contract set a new AddressManagerAddress:",
            address(newAddressManager)
        );
    }
}
