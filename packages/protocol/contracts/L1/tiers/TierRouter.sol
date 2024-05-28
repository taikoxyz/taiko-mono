// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "./ITierRouter.sol";

/// @title TierProviderBase
/// @dev Labeled in AddressResolver as "tier_router"
/// @custom:security-contact security@taiko.xyz
contract TierRouter is EssentialContract, ITierRouter {
    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ITierRouter
    function getProvider(uint256 /*_blockId*/ ) external pure returns (address) {
        return 0x4cffe56C947E26D07C14020499776DB3e9AE3a23;
    }
}
