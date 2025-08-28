// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/BaseEssentialContract.sol";

/// @title ShastaEssentialContract
/// @notice Shasta-specific version of EssentialContract with reduced storage gap to accommodate
/// forced inclusion storage while maintaining backward compatibility with existing Inbox deployments
/// @dev This contract is identical to EssentialContract except:
///      - Reduced __gap from [49] to [10] to free slots 212-250 for forced inclusion storage
///      - Maintains exact same functionality and slot layout up to slot 211
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaEssentialContract is BaseEssentialContract {
    /// @dev Reduced gap to make room for forced inclusion storage at slots 212-250
    /// This maintains backward compatibility with existing Inbox contracts that expect
    /// their storage to start at slot 251
    uint256[10] private __gap;
}