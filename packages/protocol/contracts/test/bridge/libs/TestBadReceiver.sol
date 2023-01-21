// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

// TODO(roger): Merge this file into TestReceiver.sol.
contract TestBadReceiver {
    receive() external payable {
        revert("can not send to this contract");
    }

    fallback() external payable {
        revert("can not send to this contract");
    }

    function transfer() public pure {
        revert("this fails");
    }
}
