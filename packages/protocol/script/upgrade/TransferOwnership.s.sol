// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "./UpgradeScript.s.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}
/// @notice As "single" owner is not desirable for protocols we need to
/// transfer ownership. BUT! Transferring ownership to a multisig also
/// does not help too much if the protocol wants to give some time for
/// the users to exit before an upgrade is effective. So implementing a
/// delay (L2Beat prefers 7 days) is essential.
/// So the usual approach is the following:
/// 1. Transfer ownership to TimeLockController contract which enforces the
/// delay
/// 2. The ownership of the TimeLockController contract shall be a multisig/DAO

/// Invokaction example:
/// forge script TransferOwnership --sig "run(address,address)"  <address>
/// <address>
contract TransferOwnership is UpgradeScript {
    function run(
        address contractAddr,
        address timeLockContract
    )
        external
        setUp
    {
        IOwnable(contractAddr).transferOwnership(timeLockContract);
        console2.log(
            contractAddr,
            " contract has a new owner:",
            address(timeLockContract)
        );
    }
}
