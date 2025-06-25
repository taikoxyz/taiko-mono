// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/libs/LibAddress.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibData
/// @custom:security-contact security@taiko.xyz
library LibData {
    bytes32 internal constant FIRST_TRAN_PARENT_HASH_PLACEHOLDER = bytes32(type(uint256).max);

    struct Env {
        I.Config config;
        address bondToken;
        address verifier;
        address inboxWrapper;
        address signalService;
        bytes32 prevSummaryHash;
    }
}
