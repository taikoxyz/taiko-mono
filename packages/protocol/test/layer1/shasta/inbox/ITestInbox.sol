// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/iface/IInbox.sol";

/// @title ITestInbox
/// @notice Common interface for all test Inbox implementations
/// @custom:security-contact security@taiko.xyz
interface ITestInbox is IInbox {
    /// @notice Set test configuration
    function setTestConfig(IInbox.Config memory _config) external;

    /// @notice Enable/disable mock blob validation
    function setMockBlobValidation(bool _useMock) external;

    /// @notice Set a mock blob hash for testing
    function setMockBlobHash(uint256 _index, bytes32 _hash) external;

    /// @notice Expose internal function for testing - set proposal hash
    function exposed_setProposalHash(uint48 _proposalId, bytes32 _hash) external;

    /// @notice Expose internal function for testing - set claim record hash
    function exposed_setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        external;
}
