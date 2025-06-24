// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/libs/LibAddress.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibData2
/// @custom:security-contact security@taiko.xyz
library LibData2 {
    struct Env {
        I.Config config;
        address bondToken;
        address verifier;
        address inboxWrapper;
        address signalService;
    }
}
