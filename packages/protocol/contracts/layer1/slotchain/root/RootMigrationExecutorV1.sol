// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IComponentConfigV2 } from "../../../shared/slotchain/iface/IComponentConfigV2.sol";
import { IRootMigrationExecutorV1 } from "./iface/IRootMigrationExecutorV1.sol";
import { LibRootBootstrapV1 } from "./libs/LibRootBootstrapV1.sol";

/// @title Immutable delayed protocol-root migration executor
/// @notice Selects at most one staged genesis root and permanently seals authority after activation.
/// @custom:security-contact security@taiko.xyz
contract RootMigrationExecutorV1 is IRootMigrationExecutorV1 {
    bytes4 private constant _RME1_MAGIC = 0x524d4531;
    bytes4 private constant _RMA1_MAGIC = 0x524d4131;
    bytes4 private constant _RMO1_MAGIC = 0x524d4f31;
    bytes4 private constant _PRF1_MAGIC = 0x50524631;
    bytes4 private constant _STG1_MAGIC = 0x53544731;
    bytes4 private constant _PRC1_MAGIC = 0x50524331;
    bytes4 private constant _RAC1_MAGIC = 0x52414331;

    bytes4 private constant _FACTORY_CONFIG_SELECTOR = 0xd7b40838;
    bytes4 private constant _FACTORY_STAGE_SELECTOR = 0x53c99a5f;
    bytes4 private constant _FACTORY_CAMPAIGN_SELECTOR = 0xe6139cad;

    uint64 private constant _MINIMUM_DELAY = 604_800;
    uint64 private constant _EXECUTION_WINDOW = 604_800;
    uint64 private constant _FACTORY_CONFIG_READ_GAS = 100_000;
    uint64 private constant _COMPONENT_CONFIG_READ_GAS = 50_000;
    uint64 private constant _FACTORY_STAGE_CALL_GAS = 1_500_000;
    uint64 private constant _POST_STAGE_RESERVE_GAS = 300_000;

    uint8 private constant _AUTHORITY_IDLE = 0;
    uint8 private constant _AUTHORITY_CANDIDATE = 1;
    uint8 private constant _AUTHORITY_ACTIVE = 2;

    uint8 private constant _OPERATION_NONE = 0;
    uint8 private constant _OPERATION_QUEUED = 1;
    uint8 private constant _OPERATION_EXECUTING = 2;
    uint8 private constant _OPERATION_STAGED = 3;
    uint8 private constant _OPERATION_ACTIVATED = 4;
    uint8 private constant _OPERATION_CANCELLED = 5;
    uint8 private constant _OPERATION_EXPIRED = 6;
    uint8 private constant _OPERATION_ABORTED = 7;

    uint8 private constant _CAMPAIGN_STAGED = 1;
    uint8 private constant _CAMPAIGN_ACTIVE = 2;
    uint8 private constant _CAMPAIGN_ABORTED = 3;

    uint256 private immutable _settlementChainId;
    address private immutable _daoProposer;
    bytes32 private immutable _configurationHash;

    struct Operation {
        uint8 state;
        uint64 nonce;
        address factory;
        bytes32 manifestHash;
        bytes32 factoryRuntimeHash;
        bytes32 factoryConfigurationHash;
        uint64 queuedAt;
        uint64 executeAfter;
        uint64 executeBefore;
        uint64 stagedGeneration;
        uint64 stagedExpiresAt;
    }

    struct Authority {
        uint8 state;
        address candidateFactory;
        bytes32 candidateOperationId;
        bytes32 candidateCampaignKey;
        address activeFactory;
        bytes32 activeOperationId;
        bytes32 activeCampaignKey;
        bytes32 activeRootReceipt;
    }

    uint64 private _nextOperationNonce = 1;
    Authority private _authority;
    mapping(bytes32 operationId => Operation operation) private _operations;

    /// @notice Initializes the independently addressed immutable bootstrap authority.
    /// @param _chainId The exact live settlement chain ID.
    /// @param _proposer The release-pinned DAO proposer allowed to queue and cancel.
    constructor(uint256 _chainId, address _proposer) {
        if (_chainId == 0 || _chainId != block.chainid || _proposer == address(0)) {
            revert InvalidExecutorConfiguration();
        }
        _settlementChainId = _chainId;
        _daoProposer = _proposer;
        _configurationHash = keccak256(
            abi.encodePacked(
                "slot-chain-root-migration-executor-config-v1",
                _chainId,
                _proposer,
                _MINIMUM_DELAY,
                _EXECUTION_WINDOW,
                _FACTORY_CONFIG_READ_GAS,
                _COMPONENT_CONFIG_READ_GAS,
                _FACTORY_STAGE_CALL_GAS,
                _POST_STAGE_RESERVE_GAS
            )
        );
    }

    /// @inheritdoc IComponentConfigV2
    function componentConfigHashV2() external view returns (bytes32 configHash_) {
        return _configurationHash;
    }

    /// @inheritdoc IRootMigrationExecutorV1
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
        )
    {
        return (
            _RME1_MAGIC,
            _settlementChainId,
            _daoProposer,
            _MINIMUM_DELAY,
            _EXECUTION_WINDOW,
            _FACTORY_CONFIG_READ_GAS,
            _COMPONENT_CONFIG_READ_GAS,
            _FACTORY_STAGE_CALL_GAS,
            _POST_STAGE_RESERVE_GAS,
            _configurationHash
        );
    }

    /// @inheritdoc IRootMigrationExecutorV1
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
        )
    {
        Authority memory authority = _authority;
        return (
            _RMA1_MAGIC,
            authority.state,
            authority.candidateFactory,
            authority.candidateOperationId,
            authority.candidateCampaignKey,
            authority.activeFactory,
            authority.activeOperationId,
            authority.activeCampaignKey,
            authority.activeRootReceipt
        );
    }

    /// @inheritdoc IRootMigrationExecutorV1
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
        )
    {
        Operation memory operation = _operations[_operationId];
        return (
            _RMO1_MAGIC,
            operation.state,
            operation.nonce,
            operation.factory,
            operation.manifestHash,
            operation.factoryRuntimeHash,
            operation.factoryConfigurationHash,
            operation.queuedAt,
            operation.executeAfter,
            operation.executeBefore
        );
    }

    /// @inheritdoc IRootMigrationExecutorV1
    function queueRootMigrationV1(
        address _factory,
        bytes32 _manifestHash,
        bytes32 _factoryRuntimeHash,
        bytes32 _factoryConfigurationHash
    )
        external
        returns (bytes32 operationId_)
    {
        uint256 factoryWord;
        assembly ("memory-safe") {
            factoryWord := calldataload(4)
        }
        if (msg.data.length != 132 || factoryWord > type(uint160).max) {
            revert NonCanonicalExecutorCalldata();
        }
        if (msg.sender != _daoProposer) revert UnauthorizedDaoProposer();
        if (_authority.state != _AUTHORITY_IDLE) revert RootAuthorityNotIdle();
        if (
            _factory == address(0) || _manifestHash == bytes32(0)
                || _factoryRuntimeHash == bytes32(0) || _factoryConfigurationHash == bytes32(0)
        ) {
            revert InvalidRootMigrationOperation();
        }

        uint64 nonce = _nextOperationNonce;
        // UINT64_MAX is the terminal, unused cursor because storing the row precedes increment.
        if (nonce == type(uint64).max) revert RootMigrationNonceExhausted();
        if (block.timestamp > type(uint64).max - _MINIMUM_DELAY - _EXECUTION_WINDOW) {
            revert RootMigrationTimestampOverflow();
        }
        uint64 queuedAt = uint64(block.timestamp);
        uint64 executeAfter = queuedAt + _MINIMUM_DELAY;
        uint64 executeBefore = executeAfter + _EXECUTION_WINDOW;

        operationId_ = _deriveOperationId(
            nonce, _factory, _manifestHash, _factoryRuntimeHash, _factoryConfigurationHash
        );
        if (_operations[operationId_].state != _OPERATION_NONE) {
            revert RootMigrationOperationExists();
        }
        _operations[operationId_] = Operation({
            state: _OPERATION_QUEUED,
            nonce: nonce,
            factory: _factory,
            manifestHash: _manifestHash,
            factoryRuntimeHash: _factoryRuntimeHash,
            factoryConfigurationHash: _factoryConfigurationHash,
            queuedAt: queuedAt,
            executeAfter: executeAfter,
            executeBefore: executeBefore,
            stagedGeneration: 0,
            stagedExpiresAt: 0
        });
        _nextOperationNonce = nonce + 1;

        emit RootMigrationQueued(
            operationId_,
            _factory,
            _manifestHash,
            _factoryRuntimeHash,
            _factoryConfigurationHash,
            nonce,
            executeAfter,
            executeBefore
        );
    }

    /// @inheritdoc IRootMigrationExecutorV1
    function executeRootMigrationV1(
        bytes32 _operationId,
        address _factory,
        bytes calldata _manifest
    )
        external
    {
        _requireCanonicalManifestCalldata(_factory, _manifest);
        Operation storage operation = _operations[_operationId];
        if (
            operation.state != _OPERATION_QUEUED || operation.factory != _factory
                || _authority.state != _AUTHORITY_IDLE || block.timestamp < operation.executeAfter
                || block.timestamp > operation.executeBefore
        ) {
            revert RootMigrationNotExecutable();
        }
        if (
            _deriveOperationId(
                        operation.nonce,
                        operation.factory,
                        operation.manifestHash,
                        operation.factoryRuntimeHash,
                        operation.factoryConfigurationHash
                    ) != _operationId || _deriveManifestHash(_manifest) != operation.manifestHash
        ) {
            revert RootMigrationIdentityMismatch();
        }
        LibRootBootstrapV1.requireRuntime(_factory, operation.factoryRuntimeHash);
        bytes32 campaignKey = _campaignKey(_factory, _manifest);
        operation.state = _OPERATION_EXECUTING;
        _authority = Authority({
            state: _AUTHORITY_CANDIDATE,
            candidateFactory: _factory,
            candidateOperationId: _operationId,
            candidateCampaignKey: campaignKey,
            activeFactory: address(0),
            activeOperationId: bytes32(0),
            activeCampaignKey: bytes32(0),
            activeRootReceipt: bytes32(0)
        });

        LibRootBootstrapV1.requireConfiguration(
            _factory, operation.factoryConfigurationHash, _COMPONENT_CONFIG_READ_GAS
        );
        _requireFactoryConfig(_factory, operation.factoryConfigurationHash);

        bytes memory stageReturn = LibRootBootstrapV1.callExact(
            _factory,
            abi.encodeWithSelector(_FACTORY_STAGE_SELECTOR, _operationId, _manifest),
            _FACTORY_STAGE_CALL_GAS,
            192,
            _POST_STAGE_RESERVE_GAS
        );
        LibRootBootstrapV1.requireMagic(stageReturn, _STG1_MAGIC);
        if (
            LibRootBootstrapV1.word(stageReturn, 1) != _operationId
                || LibRootBootstrapV1.word(stageReturn, 2) != campaignKey
                || LibRootBootstrapV1.word(stageReturn, 3) != operation.manifestHash
        ) {
            revert InvalidFactoryStageReceipt();
        }
        uint64 generation = LibRootBootstrapV1.u64Word(stageReturn, 4);
        uint64 expiresAt = LibRootBootstrapV1.u64Word(stageReturn, 5);
        _requireCampaignState(
            _factory,
            _operationId,
            campaignKey,
            operation.manifestHash,
            _CAMPAIGN_STAGED,
            generation,
            expiresAt,
            0,
            false,
            bytes32(0)
        );

        operation.stagedGeneration = generation;
        operation.stagedExpiresAt = expiresAt;
        operation.state = _OPERATION_STAGED;
        emit RootMigrationStaged(_operationId, campaignKey, generation, expiresAt);
    }

    /// @inheritdoc IRootMigrationExecutorV1
    function cancelRootMigrationV1(bytes32 _operationId) external {
        if (msg.data.length != 36) revert NonCanonicalExecutorCalldata();
        if (msg.sender != _daoProposer) revert UnauthorizedDaoProposer();
        Operation storage operation = _operations[_operationId];
        if (operation.state != _OPERATION_QUEUED) revert RootMigrationNotCancellable();
        operation.state = _OPERATION_CANCELLED;
        emit RootMigrationCancelled(_operationId);
    }

    /// @inheritdoc IRootMigrationExecutorV1
    function expireRootMigrationV1(bytes32 _operationId) external {
        if (msg.data.length != 36) revert NonCanonicalExecutorCalldata();
        Operation storage operation = _operations[_operationId];
        if (operation.state != _OPERATION_QUEUED || block.timestamp <= operation.executeBefore) {
            revert RootMigrationNotExpired();
        }
        operation.state = _OPERATION_EXPIRED;
        emit RootMigrationExpired(_operationId);
    }

    /// @inheritdoc IRootMigrationExecutorV1
    function confirmRootMigrationV1(
        bytes32 _operationId,
        bytes32 _campaignKeyValue,
        bytes32 _rootReceipt
    )
        external
        returns (bytes4 magic_)
    {
        if (msg.data.length != 100) revert NonCanonicalExecutorCalldata();
        Authority memory authority = _authority;
        Operation storage operation = _operations[_operationId];
        if (
            authority.state != _AUTHORITY_CANDIDATE || msg.sender != authority.candidateFactory
                || authority.candidateOperationId != _operationId
                || authority.candidateCampaignKey != _campaignKeyValue
                || operation.state != _OPERATION_STAGED || operation.factory != msg.sender
                || _rootReceipt == bytes32(0)
        ) {
            revert InvalidRootActivationConfirmation();
        }
        LibRootBootstrapV1.requireRuntime(msg.sender, operation.factoryRuntimeHash);
        LibRootBootstrapV1.requireConfiguration(
            msg.sender, operation.factoryConfigurationHash, _COMPONENT_CONFIG_READ_GAS
        );
        _requireCampaignState(
            msg.sender,
            _operationId,
            _campaignKeyValue,
            operation.manifestHash,
            _CAMPAIGN_ACTIVE,
            operation.stagedGeneration,
            operation.stagedExpiresAt,
            0x01ff,
            false,
            _rootReceipt
        );

        operation.state = _OPERATION_ACTIVATED;
        _authority = Authority({
            state: _AUTHORITY_ACTIVE,
            candidateFactory: address(0),
            candidateOperationId: bytes32(0),
            candidateCampaignKey: bytes32(0),
            activeFactory: msg.sender,
            activeOperationId: _operationId,
            activeCampaignKey: _campaignKeyValue,
            activeRootReceipt: _rootReceipt
        });
        emit RootMigrationActivated(_operationId, _campaignKeyValue, _rootReceipt);
        return _RAC1_MAGIC;
    }

    /// @inheritdoc IRootMigrationExecutorV1
    function clearAbortedRootMigrationV1(
        bytes32 _operationId,
        bytes32 _campaignKeyValue
    )
        external
    {
        if (msg.data.length != 68) revert NonCanonicalExecutorCalldata();
        Authority memory authority = _authority;
        Operation storage operation = _operations[_operationId];
        if (
            authority.state != _AUTHORITY_CANDIDATE
                || authority.candidateOperationId != _operationId
                || authority.candidateCampaignKey != _campaignKeyValue
                || operation.state != _OPERATION_STAGED
                || operation.factory != authority.candidateFactory
        ) {
            revert InvalidAbortedRootCandidate();
        }
        LibRootBootstrapV1.requireRuntime(operation.factory, operation.factoryRuntimeHash);
        LibRootBootstrapV1.requireConfiguration(
            operation.factory, operation.factoryConfigurationHash, _COMPONENT_CONFIG_READ_GAS
        );
        _requireCampaignState(
            operation.factory,
            _operationId,
            _campaignKeyValue,
            operation.manifestHash,
            _CAMPAIGN_ABORTED,
            operation.stagedGeneration,
            operation.stagedExpiresAt,
            0x01ff,
            true,
            bytes32(0)
        );

        operation.state = _OPERATION_ABORTED;
        delete _authority;
        emit RootMigrationCandidateCleared(_operationId, _campaignKeyValue);
    }

    /// @dev Validates PRF1's exact immutable Executor binding and configuration result.
    function _requireFactoryConfig(address _factory, bytes32 _expectedConfig) private view {
        bytes memory raw = LibRootBootstrapV1.staticcallExact(
            _factory,
            abi.encodeWithSelector(_FACTORY_CONFIG_SELECTOR),
            _FACTORY_CONFIG_READ_GAS,
            544
        );
        LibRootBootstrapV1.requireMagic(raw, _PRF1_MAGIC);
        bytes32 executorRuntimeHash;
        assembly ("memory-safe") {
            executorRuntimeHash := extcodehash(address())
        }
        if (
            uint256(LibRootBootstrapV1.word(raw, 1)) != _settlementChainId
                || LibRootBootstrapV1.word(raw, 2) == bytes32(0)
                || LibRootBootstrapV1.addressWord(raw, 3) != address(this)
                || LibRootBootstrapV1.word(raw, 4) != executorRuntimeHash
                || LibRootBootstrapV1.word(raw, 5) != _configurationHash
                || LibRootBootstrapV1.word(raw, 6) == bytes32(0)
                || LibRootBootstrapV1.word(raw, 7) == bytes32(0)
                || LibRootBootstrapV1.u64Word(raw, 8) != 2_592_000
                || LibRootBootstrapV1.u64Word(raw, 9) != 500_000
                || LibRootBootstrapV1.u8Word(raw, 10) != 18
                || LibRootBootstrapV1.u64Word(raw, 11) != 100_000
                || LibRootBootstrapV1.u64Word(raw, 12) != 50_000
                || LibRootBootstrapV1.u64Word(raw, 13) != 50_000
                || LibRootBootstrapV1.u64Word(raw, 14) != 100_000
                || LibRootBootstrapV1.u64Word(raw, 15) != 500_000
                || LibRootBootstrapV1.word(raw, 16) != _expectedConfig
        ) {
            revert InvalidFactoryConfiguration();
        }
    }

    /// @dev Exact-reads PRC1 and checks the selected state plus optional sentinel-skipped fields.
    function _requireCampaignState(
        address _factory,
        bytes32 _operationId,
        bytes32 _campaignKeyValue,
        bytes32 _manifestHashValue,
        uint8 _state,
        uint64 _generation,
        uint64 _expiresAt,
        uint16 _deployedBitmap,
        bool _allowBitmapSubset,
        bytes32 _rootReceipt
    )
        private
        view
    {
        bytes memory raw = LibRootBootstrapV1.staticcallExact(
            _factory,
            abi.encodeWithSelector(_FACTORY_CAMPAIGN_SELECTOR, _campaignKeyValue),
            _FACTORY_CONFIG_READ_GAS,
            288
        );
        LibRootBootstrapV1.requireMagic(raw, _PRC1_MAGIC);
        uint64 observedGeneration = LibRootBootstrapV1.u64Word(raw, 5);
        uint64 observedExpiresAt = LibRootBootstrapV1.u64Word(raw, 6);
        uint16 observedBitmap = LibRootBootstrapV1.u16Word(raw, 7);
        if (
            LibRootBootstrapV1.word(raw, 1) != _operationId
                || LibRootBootstrapV1.word(raw, 2) != _campaignKeyValue
                || LibRootBootstrapV1.word(raw, 3) != _manifestHashValue
                || LibRootBootstrapV1.u8Word(raw, 4) != _state || observedGeneration != _generation
                || observedExpiresAt != _expiresAt
                || (_allowBitmapSubset
                        ? (observedBitmap & ~_deployedBitmap) != 0
                        : observedBitmap != _deployedBitmap)
                || LibRootBootstrapV1.word(raw, 8) != _rootReceipt
        ) {
            revert InvalidFactoryCampaignState();
        }
    }

    /// @dev Derives the exact operation identity from its immutable stored row.
    function _deriveOperationId(
        uint64 _nonce,
        address _factory,
        bytes32 _manifestHashValue,
        bytes32 _runtimeHash,
        bytes32 _configHash
    )
        private
        view
        returns (bytes32 operationId_)
    {
        return keccak256(
            abi.encodePacked(
                "slot-chain-root-migration-operation-v1",
                _settlementChainId,
                address(this),
                _nonce,
                _factory,
                _manifestHashValue,
                _runtimeHash,
                _configHash
            )
        );
    }

    /// @dev Derives the manifest commitment with its pinned width prefix.
    function _deriveManifestHash(bytes calldata _manifest) private pure returns (bytes32 hash_) {
        return keccak256(
            abi.encodePacked("slot-chain-protocol-root-manifest-v1", uint16(969), _manifest)
        );
    }

    /// @dev Parses only the campaign header after the exact manifest length is established.
    function _campaignKey(
        address _factory,
        bytes calldata _manifest
    )
        private
        view
        returns (bytes32 key_)
    {
        uint8 schema;
        uint256 chainId;
        uint64 generation;
        bytes32 namespace;
        bytes32 predecessor;
        assembly ("memory-safe") {
            schema := byte(0, calldataload(_manifest.offset))
            chainId := calldataload(add(_manifest.offset, 1))
            generation := shr(192, calldataload(add(_manifest.offset, 33)))
            namespace := calldataload(add(_manifest.offset, 41))
            predecessor := calldataload(add(_manifest.offset, 73))
        }
        if (
            schema != 1 || chainId != _settlementChainId || namespace == bytes32(0)
                || predecessor != bytes32(0) || generation == type(uint64).max
        ) {
            revert InvalidProtocolRootManifestHeader();
        }
        return keccak256(
            abi.encodePacked(
                "slot-chain-protocol-root-campaign-v1",
                chainId,
                _factory,
                generation,
                namespace,
                predecessor
            )
        );
    }

    /// @dev Enforces the canonical execute ABI before any Factory read or authority write.
    function _requireCanonicalManifestCalldata(
        address _factory,
        bytes calldata _manifest
    )
        private
        pure
    {
        uint256 addressWordValue;
        uint256 dynamicOffset;
        uint256 dynamicLength;
        assembly ("memory-safe") {
            addressWordValue := calldataload(36)
            dynamicOffset := calldataload(68)
            dynamicLength := calldataload(100)
        }
        if (
            _factory == address(0) || addressWordValue > type(uint160).max || dynamicOffset != 96
                || dynamicLength != 969 || _manifest.length != 969 || msg.data.length != 1124
        ) {
            revert NonCanonicalExecutorCalldata();
        }
        // The 969-byte manifest has 23 bytes of padding in its last ABI word.
        uint256 finalWord;
        assembly ("memory-safe") {
            finalWord := calldataload(add(_manifest.offset, 960))
        }
        if ((finalWord & ((uint256(1) << 184) - 1)) != 0) {
            revert NonCanonicalExecutorCalldata();
        }
    }

    error InvalidAbortedRootCandidate();
    error InvalidExecutorConfiguration();
    error InvalidFactoryCampaignState();
    error InvalidFactoryConfiguration();
    error InvalidFactoryStageReceipt();
    error InvalidProtocolRootManifestHeader();
    error InvalidRootActivationConfirmation();
    error InvalidRootMigrationOperation();
    error NonCanonicalExecutorCalldata();
    error RootAuthorityNotIdle();
    error RootMigrationIdentityMismatch();
    error RootMigrationNonceExhausted();
    error RootMigrationNotCancellable();
    error RootMigrationNotExecutable();
    error RootMigrationNotExpired();
    error RootMigrationOperationExists();
    error RootMigrationTimestampOverflow();
    error UnauthorizedDaoProposer();
}
