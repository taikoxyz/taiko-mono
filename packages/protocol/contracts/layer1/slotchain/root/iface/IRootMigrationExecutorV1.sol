// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IComponentConfigV2 } from "../../../../shared/slotchain/iface/IComponentConfigV2.sol";

/// @title Delayed protocol-root migration executor interface
/// @custom:security-contact security@taiko.xyz
interface IRootMigrationExecutorV1 is IComponentConfigV2 {
    event RootMigrationQueued(
        bytes32 indexed operationId,
        address indexed factory,
        bytes32 indexed manifestHash,
        bytes32 factoryRuntimeHash,
        bytes32 factoryConfigurationHash,
        uint64 nonce,
        uint64 executeAfter,
        uint64 executeBefore
    );
    event RootMigrationStaged(
        bytes32 indexed operationId,
        bytes32 indexed campaignKey,
        uint64 indexed generation,
        uint64 expiresAt
    );
    event RootMigrationActivated(
        bytes32 indexed operationId, bytes32 indexed campaignKey, bytes32 indexed rootReceipt
    );
    event RootMigrationCandidateCleared(bytes32 indexed operationId, bytes32 indexed campaignKey);
    event RootMigrationCancelled(bytes32 indexed operationId);
    event RootMigrationExpired(bytes32 indexed operationId);

    /// @notice Queues one immutable Factory/manifest operation under the fixed delay.
    /// @param _factory The exact immutable protocol-root factory.
    /// @param _manifestHash The hash of the exact 969-byte root manifest.
    /// @param _factoryRuntimeHash The expected live Factory EXTCODEHASH.
    /// @param _factoryConfigurationHash The expected Factory component configuration.
    /// @return operationId_ The unique operation identity.
    function queueRootMigrationV1(
        address _factory,
        bytes32 _manifestHash,
        bytes32 _factoryRuntimeHash,
        bytes32 _factoryConfigurationHash
    )
        external
        returns (bytes32 operationId_);

    /// @notice Executes one mature queued operation and atomically authenticates Factory staging.
    /// @param _operationId The queued operation identity.
    /// @param _factory The exact Factory repeated as a race and substitution guard.
    /// @param _manifest The canonical packed 969-byte root manifest.
    function executeRootMigrationV1(
        bytes32 _operationId,
        address _factory,
        bytes calldata _manifest
    )
        external;

    /// @notice Cancels a still-queued operation before execution starts.
    /// @param _operationId The queued operation identity.
    function cancelRootMigrationV1(bytes32 _operationId) external;

    /// @notice Permissionlessly expires a queued operation strictly after its execution window.
    /// @param _operationId The queued operation identity.
    function expireRootMigrationV1(bytes32 _operationId) external;

    /// @notice Confirms the candidate Factory's atomically published active root.
    /// @param _operationId The staged operation identity.
    /// @param _campaignKey The staged campaign key.
    /// @param _rootReceipt The Factory-published nonzero root receipt.
    /// @return magic_ The RAC1 acknowledgement.
    function confirmRootMigrationV1(
        bytes32 _operationId,
        bytes32 _campaignKey,
        bytes32 _rootReceipt
    )
        external
        returns (bytes4 magic_);

    /// @notice Clears one authenticated, expired and Factory-aborted candidate.
    /// @param _operationId The staged operation identity.
    /// @param _campaignKey The aborted campaign key.
    function clearAbortedRootMigrationV1(
        bytes32 _operationId,
        bytes32 _campaignKey
    )
        external;

    /// @notice Returns the immutable executor configuration.
    /// @return magic_ The RME1 response magic.
    /// @return settlementChainId_ The bound L1 chain ID.
    /// @return daoProposer_ The sole queue/cancel proposer.
    /// @return minimumDelay_ The queue delay in seconds.
    /// @return executionWindow_ The inclusive execution-window width in seconds.
    /// @return factoryConfigReadGas_ The PRF1/PRC1 read stipend.
    /// @return componentConfigReadGas_ The component-config read stipend.
    /// @return factoryStageCallGas_ The exact Factory staging call stipend.
    /// @return postStageReserveGas_ The gas retained after the stage call.
    /// @return configurationHash_ The derived executor configuration hash.
    function rootMigrationExecutorConfigV1()
        external
        view
        returns (
            bytes4 magic_,
            uint256 settlementChainId_,
            address daoProposer_,
            uint64 minimumDelay_,
            uint64 executionWindow_,
            uint64 factoryConfigReadGas_,
            uint64 componentConfigReadGas_,
            uint64 factoryStageCallGas_,
            uint64 postStageReserveGas_,
            bytes32 configurationHash_
        );

    /// @notice Returns the unique global root authority state.
    /// @return magic_ The RMA1 response magic.
    /// @return state_ IDLE=0, CANDIDATE=1, or ACTIVE=2.
    /// @return candidateFactory_ The current candidate Factory, or zero outside CANDIDATE.
    /// @return candidateOperationId_ The candidate operation, or zero outside CANDIDATE.
    /// @return candidateCampaignKey_ The candidate campaign, or zero outside CANDIDATE.
    /// @return activeFactory_ The installed Factory, or zero outside ACTIVE.
    /// @return activeOperationId_ The installed operation, or zero outside ACTIVE.
    /// @return activeCampaignKey_ The installed campaign, or zero outside ACTIVE.
    /// @return activeRootReceipt_ The installed root receipt, or zero outside ACTIVE.
    function rootMigrationAuthorityV1()
        external
        view
        returns (
            bytes4 magic_,
            uint8 state_,
            address candidateFactory_,
            bytes32 candidateOperationId_,
            bytes32 candidateCampaignKey_,
            address activeFactory_,
            bytes32 activeOperationId_,
            bytes32 activeCampaignKey_,
            bytes32 activeRootReceipt_
        );

    /// @notice Returns one immutable operation row and its state.
    /// @param _operationId The operation identity, or an unknown key for the canonical NONE row.
    /// @return magic_ The RMO1 response magic.
    /// @return state_ NONE=0, QUEUED=1, EXECUTING=2, STAGED=3, ACTIVATED=4, CANCELLED=5,
    ///         EXPIRED=6, or ABORTED=7.
    /// @return nonce_ The operation nonce.
    /// @return factory_ The queued Factory.
    /// @return manifestHash_ The committed manifest hash.
    /// @return factoryRuntimeHash_ The committed Factory runtime hash.
    /// @return factoryConfigurationHash_ The committed Factory configuration hash.
    /// @return queuedAt_ The queue timestamp.
    /// @return executeAfter_ The inclusive first execution timestamp.
    /// @return executeBefore_ The inclusive last execution timestamp.
    function rootMigrationOperationV1(bytes32 _operationId)
        external
        view
        returns (
            bytes4 magic_,
            uint8 state_,
            uint64 nonce_,
            address factory_,
            bytes32 manifestHash_,
            bytes32 factoryRuntimeHash_,
            bytes32 factoryConfigurationHash_,
            uint64 queuedAt_,
            uint64 executeAfter_,
            uint64 executeBefore_
        );
}
