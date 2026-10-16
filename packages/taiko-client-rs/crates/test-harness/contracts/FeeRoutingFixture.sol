// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Real EVM effects for the fee-routing acceptance suite.
contract FeeRoutingFixture {
    uint256 public value;

    /// @notice Writes a nonzero storage value before the refund test.
    function set() external { value = 1; }

    /// @notice Clears storage to exercise the EIP-3529 refund.
    function clear() external { value = 0; }

    /// @notice Writes in the caller's delegated account under EIP-7702.
    function increment() external { value += 1; }

    /// @notice Reverts while still charging transaction fees.
    function fail() external pure { revert ExpectedRevert(); }

    /// @notice Ignores arbitrary calldata to exercise EIP-7623's floor.
    fallback() external { }

    /// @notice Forces a non-fee credit into a vault without invoking its code.
    /// @param target The destination of the forced credit.
    function forceCredit(address payable target) external payable {
        new ForceCredit{value: msg.value}(target);
    }

    error ExpectedRevert();
}

/// @notice A same-transaction selfdestruct transfer, valid after EIP-6780.
contract ForceCredit {
    /// @notice Sends the creation value unconditionally to the target.
    /// @param target The destination of the forced credit.
    constructor(address payable target) payable { selfdestruct(target); }
}
