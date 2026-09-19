// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IComponentConfigV2 } from "../../../../shared/slotchain/iface/IComponentConfigV2.sol";

/// @title Staged protocol-root factory interface
/// @custom:security-contact security@taiko.xyz
interface IProtocolRootFactoryV1 is IComponentConfigV2 {
    /// @notice Exact static PRF1 configuration row.
    struct ProtocolRootFactoryConfigV1 {
        bytes4 magic;
        uint256 settlementChainId;
        bytes32 manifestNamespace;
        address delayedExecutor;
        bytes32 executorRuntimeHash;
        bytes32 executorConfigurationHash;
        bytes32 proxyCreationCodeHash;
        bytes32 proxyRuntimeHash;
        uint64 campaignLifetime;
        uint64 deploymentPostcheckReserve;
        uint8 minimumFirstManagedRunwayWindows;
        uint64 executorConfigReadGas;
        uint64 componentConfigReadGas;
        uint64 activationCallGas;
        uint64 externalReadGas;
        uint64 executorConfirmCallGas;
        bytes32 configurationHash;
    }

    event ProtocolRootCampaignStaged(
        bytes32 indexed campaignKey,
        bytes32 indexed manifestHash,
        uint64 indexed generation,
        bytes32 operationId,
        uint64 expiresAt
    );
    event ProtocolRootComponentDeployed(
        bytes32 indexed campaignKey,
        uint64 indexed generation,
        uint8 indexed role,
        address component
    );
    event ProtocolRootActivated(
        bytes32 indexed campaignKey, bytes32 indexed rootReceipt, uint64 indexed generation
    );
    event ProtocolRootCampaignAborted(bytes32 indexed campaignKey, uint64 indexed generation);

    /// @notice Stages one canonical delayed-executor-authorized root manifest.
    /// @param _operationId The active Executor candidate operation.
    /// @param _manifest The exact packed 969-byte root manifest.
    /// @return magic_ The STG1 receipt magic.
    /// @return operationId_ The accepted operation identity.
    /// @return campaignKey_ The code-independent campaign key.
    /// @return manifestHash_ The exact manifest commitment.
    /// @return generation_ The staged generation.
    /// @return expiresAt_ The inclusive campaign deadline.
    function stageProtocolRootV1(
        bytes32 _operationId,
        bytes calldata _manifest
    )
        external
        returns (
            bytes4 magic_,
            bytes32 operationId_,
            bytes32 campaignKey_,
            bytes32 manifestHash_,
            uint64 generation_,
            uint64 expiresAt_
        );

    /// @notice Deploys and postvalidates one manifest role through its fixed CREATE3 proxy.
    /// @param _campaignKey The live campaign key.
    /// @param _role The role in the closed interval 1..9.
    /// @param _initCode The exact manifest-committed role init code.
    /// @return component_ The deterministic role component address.
    function deployProtocolRootComponentV1(
        bytes32 _campaignKey,
        uint8 _role,
        bytes calldata _initCode
    )
        external
        returns (address component_);

    /// @notice Atomically validates, activates, publishes, and Executor-confirms all nine roles.
    /// @param _campaignKey The fully deployed live campaign.
    /// @return rootReceipt_ The unique installed root receipt.
    function finalizeProtocolRootV1(bytes32 _campaignKey) external returns (bytes32 rootReceipt_);

    /// @notice Marks an expired partial campaign ABORTED so the Executor can clear it.
    /// @param _campaignKey The expired live campaign.
    function abortProtocolRootCampaignV1(bytes32 _campaignKey) external;

    /// @notice Returns immutable Factory deployment configuration.
    /// @return config_ The 17-field static PRF1 configuration row.
    function protocolRootFactoryConfigV1()
        external
        view
        returns (ProtocolRootFactoryConfigV1 memory config_);

    /// @notice Returns one campaign row or the canonical NONE row.
    function protocolRootCampaignV1(bytes32 _campaignKey)
        external
        view
        returns (
            bytes4 magic_,
            bytes32 operationId_,
            bytes32 key_,
            bytes32 manifestHash_,
            uint8 state_,
            uint64 generation_,
            uint64 expiresAt_,
            uint16 deployedBitmap_,
            bytes32 rootReceipt_
        );

    /// @notice Returns one staged role descriptor or the canonical empty row.
    function protocolRootComponentV1(
        bytes32 _campaignKey,
        uint8 _role
    )
        external
        view
        returns (
            bytes4 magic_,
            bytes32 key_,
            uint8 role_,
            address component_,
            bytes32 initCodeHash_,
            bytes32 runtimeHash_,
            bytes32 configurationHash_
        );
}
