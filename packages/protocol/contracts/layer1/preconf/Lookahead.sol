// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../shared/common/EssentialContract.sol";
import "./ILookahead.sol";

/// @title PreconfTaskManager.sol
/// @custom:security-contact security@taiko.xyz
contract Lookahead is ILookahead, EssentialContract {
    function isCurrentPreconfer(address addr) external view returns (bool) {
        return true;
    }
}
