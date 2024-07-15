// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ITierRouter.sol";

/// @title TierRouter
/// @dev Labeled in AddressResolver as "tier_router"
/// @custom:security-contact security@taiko.xyz
contract TierRouter is ITierRouter {
    /// @inheritdoc ITierRouter
    function getProvider(uint256 /*_blockId*/ ) external pure returns (address) {
        return 0x4cffe56C947E26D07C14020499776DB3e9AE3a23;
    }
}
