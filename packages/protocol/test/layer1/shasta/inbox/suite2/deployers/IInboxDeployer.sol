// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";

/// @title IInboxDeployer
/// @notice Interface for deploying different Inbox implementations
interface IInboxDeployer {
    /// @notice Deploy an Inbox instance with the given dependencies
    /// @param bondToken The token used for bonds
    /// @param syncedBlockManager The synced block manager contract
    /// @param proofVerifier The proof verifier contract
    /// @param proposerChecker The proposer checker contract
    /// @return The deployed Inbox instance
    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker
    )
        external
        returns (Inbox);

    /// @notice Get the name of the test contract for snapshot identification
    /// @return The test contract name
    function getTestContractName() external pure returns (string memory);
}
