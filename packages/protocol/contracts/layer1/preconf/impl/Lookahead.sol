// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/common/EssentialContract.sol";
import "../iface/ILookahead.sol";
import "../libs/LibNames.sol";

/// @title PreconfTaskManager.sol
/// @custom:security-contact security@taiko.xyz
contract Lookahead is ILookahead, EssentialContract {
    function updateLookahead(LookaheadSetParam calldata _lookaheadSetParams)
        external
        nonReentrant
        onlyFromNamed(LibNames.B_PRECONF_SERVICE_MANAGER)
    { }

    function isCurrentPreconfer(address addr) external view returns (bool) {
        //
    }

    function isLookaheadRequired() public view returns (bool) {
        // TODO
    }
}
