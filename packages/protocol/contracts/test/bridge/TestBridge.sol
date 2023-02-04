// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../bridge/Bridge.sol";

contract TestBridge is Bridge {
    // The following custom errors allow for integration tests
    // to pass. When more integration tests are added, more custom
    // errors may need to be copied from LibXXX.sol libraries.
    error ErrProcessInvalidSender();
    error ErrProcessInvalidDestinationChain();
    error ErrProcessInvalidMessageStatus();
    error ErrProcessMessageNotReceived();
}
