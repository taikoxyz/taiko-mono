// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "./ITierRouter.sol";

/// @title TierProviderBase
/// @custom:security-contact security@taiko.xyz
abstract contract TierRouter is EssentialContract, ITierRouter {
    uint256[50] private __gap;

    /// @inheritdoc ITierRouter
    function getProvider(uint256 /*_blockId*/ ) external pure returns (address) {
        return 0x4cffe56C947E26D07C14020499776DB3e9AE3a23;
    }
}
