// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title CrossChainRelay
/// @notice A stateless, fundless relay that receives bridge messages via onMessageInvocation
///         and forwards them to arbitrary target contracts. This ensures the target
///         sees the relay as msg.sender (not the bridge), avoiding trust issues.
/// @dev This contract is intentionally permissionless — it holds no funds, no authority,
///      and no privileged state. It simply relays calldata. Restricting callers to the
///      bridge would add complexity without security benefit: the relay has nothing to
///      protect. Any address can call it, and the worst case is a no-op forwarded call.
/// @custom:security-contact security@taiko.xyz
contract CrossChainRelay {
    /// @notice Called by the bridge when processing a cross-chain message.
    /// @param _data ABI-encoded (address target, bytes callData) to forward.
    function onMessageInvocation(bytes calldata _data) external payable {
        (address target, bytes memory callData) = abi.decode(_data, (address, bytes));
        (bool success, bytes memory returnData) = target.call{ value: msg.value }(callData);
        if (!success) {
            // Bubble up the revert reason
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }
}
