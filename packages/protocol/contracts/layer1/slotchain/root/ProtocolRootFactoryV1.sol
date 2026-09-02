// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IComponentConfigV2 } from "../../../shared/slotchain/iface/IComponentConfigV2.sol";
import {
    IProtocolRootActivationV1
} from "../../../shared/slotchain/iface/IProtocolRootActivationV1.sol";
import { ProtocolRootCreate3ProxyV1 } from "./ProtocolRootCreate3ProxyV1.sol";
import { IProtocolRootFactoryV1 } from "./iface/IProtocolRootFactoryV1.sol";
import { LibRootBootstrapV1 } from "./libs/LibRootBootstrapV1.sol";

/// @title Immutable staged protocol-root factory
/// @notice Deploys exactly one nine-role genesis root through retryable CREATE3 campaigns.
/// @custom:security-contact security@taiko.xyz
contract ProtocolRootFactoryV1 is IProtocolRootFactoryV1 {
    bytes4 private constant _PRF1_MAGIC = 0x50524631;
    bytes4 private constant _PRC1_MAGIC = 0x50524331;
    bytes4 private constant _PRD1_MAGIC = 0x50524431;
    bytes4 private constant _STG1_MAGIC = 0x53544731;
    bytes4 private constant _PRA1_MAGIC = 0x50524131;
    bytes4 private constant _RAA1_MAGIC = 0x52414131;
    bytes4 private constant _RAC1_MAGIC = 0x52414331;
    bytes4 private constant _RME1_MAGIC = 0x524d4531;
    bytes4 private constant _RMA1_MAGIC = 0x524d4131;
    bytes4 private constant _BRC1_MAGIC = 0x42524331;
    bytes4 private constant _SOC1_MAGIC = 0x534f4331;
    bytes4 private constant _PCT1_MAGIC = 0x50435431;
    bytes4 private constant _PVM1_MAGIC = 0x50564d31;

    bytes4 private constant _EXECUTOR_CONFIG_SELECTOR = 0xe9d1d099;
    bytes4 private constant _EXECUTOR_AUTHORITY_SELECTOR = 0xccf788d5;
    bytes4 private constant _EXECUTOR_CONFIRM_SELECTOR = 0xb1372f22;
    bytes4 private constant _ACTIVATION_VIEW_SELECTOR = 0xda930d69;
    bytes4 private constant _ACTIVATE_SELECTOR = 0x74e3aa45;
    bytes4 private constant _BRC1_SELECTOR = 0x66f0bd82;
    bytes4 private constant _SOC1_SELECTOR = 0xe3d91a33;
    bytes4 private constant _PCT1_SELECTOR = 0xb80095ca;
    bytes4 private constant _PVM1_SELECTOR = 0x4deb7821;

    bytes32 private constant _PROTOCOL_CHANGE_OPERATION_DOMAIN =
        keccak256("slot-chain-protocol-change-operation-v1");

    uint64 private constant _CAMPAIGN_LIFETIME = 2_592_000;
    uint64 private constant _DEPLOYMENT_POSTCHECK_RESERVE = 500_000;
    uint8 private constant _MINIMUM_FIRST_MANAGED_RUNWAY_WINDOWS = 18;
    uint64 private constant _EXECUTOR_CONFIG_READ_GAS = 100_000;
    uint64 private constant _COMPONENT_CONFIG_READ_GAS = 50_000;
    uint64 private constant _ACTIVATION_CALL_GAS = 50_000;
    uint64 private constant _EXTERNAL_READ_GAS = 100_000;
    uint64 private constant _EXECUTOR_CONFIRM_CALL_GAS = 500_000;

    uint8 private constant _CAMPAIGN_NONE = 0;
    uint8 private constant _CAMPAIGN_STAGED = 1;
    uint8 private constant _CAMPAIGN_ACTIVE = 2;
    uint8 private constant _CAMPAIGN_ABORTED = 3;
    uint16 private constant _ALL_ROLES_BITMAP = 0x01ff;

    uint256 private immutable _settlementChainId;
    bytes32 private immutable _manifestNamespace;
    address private immutable _delayedExecutor;
    address private immutable _daoProposer;
    bytes32 private immutable _executorRuntimeHash;
    bytes32 private immutable _executorConfigurationHash;
    bytes32 private immutable _proxyCreationCodeHash;
    bytes32 private immutable _proxyRuntimeHash;
    bytes32 private immutable _configurationHash;

    struct Campaign {
        bytes32 operationId;
        bytes32 key;
        bytes32 manifestHash;
        uint8 state;
        uint64 generation;
        uint64 expiresAt;
        uint16 deployedBitmap;
        bytes32 rootReceipt;
    }

    struct ComponentDescriptor {
        address component;
        bytes32 initCodeHash;
        bytes32 runtimeHash;
        bytes32 configurationHash;
    }

    struct StageContext {
        bytes32 campaignKey;
        bytes32 manifestHash;
        uint64 generation;
        uint64 expiresAt;
    }

    uint64 private _nextGeneration;
    bytes32 private _liveCampaignKey;
    bytes32 private _activeRootReceipt;
    mapping(bytes32 campaignKey => Campaign campaign) private _campaigns;
    mapping(bytes32 campaignKey => mapping(uint8 role => ComponentDescriptor descriptor)) private
        _components;

    /// @notice Initializes one immutable Factory bound to the independently deployed Executor.
    constructor(
        uint256 _chainId,
        bytes32 _namespace,
        address _executor,
        bytes32 _expectedExecutorRuntimeHash,
        bytes32 _expectedExecutorConfigurationHash
    ) {
        if (
            _chainId == 0 || _chainId != block.chainid || _namespace == bytes32(0)
                || _executor == address(0) || _expectedExecutorRuntimeHash == bytes32(0)
                || _expectedExecutorConfigurationHash == bytes32(0)
        ) {
            revert InvalidFactoryConfiguration();
        }
        LibRootBootstrapV1.requireRuntime(_executor, _expectedExecutorRuntimeHash);
        LibRootBootstrapV1.requireConfiguration(
            _executor, _expectedExecutorConfigurationHash, _COMPONENT_CONFIG_READ_GAS
        );

        bytes32 proxyCreationCodeHash = keccak256(type(ProtocolRootCreate3ProxyV1).creationCode);
        bytes32 proxyRuntimeHash = keccak256(type(ProtocolRootCreate3ProxyV1).runtimeCode);
        _settlementChainId = _chainId;
        _manifestNamespace = _namespace;
        _delayedExecutor = _executor;
        _executorRuntimeHash = _expectedExecutorRuntimeHash;
        _executorConfigurationHash = _expectedExecutorConfigurationHash;
        _proxyCreationCodeHash = proxyCreationCodeHash;
        _proxyRuntimeHash = proxyRuntimeHash;
        bytes memory configurationIdentity = abi.encodePacked(
            "slot-chain-protocol-root-factory-config-v1",
            _chainId,
            _namespace,
            _executor,
            _expectedExecutorRuntimeHash,
            _expectedExecutorConfigurationHash,
            proxyCreationCodeHash,
            proxyRuntimeHash
        );
        bytes memory configurationPolicy = abi.encodePacked(
            _CAMPAIGN_LIFETIME,
            _DEPLOYMENT_POSTCHECK_RESERVE,
            _MINIMUM_FIRST_MANAGED_RUNWAY_WINDOWS,
            _EXECUTOR_CONFIG_READ_GAS,
            _COMPONENT_CONFIG_READ_GAS,
            _ACTIVATION_CALL_GAS,
            _EXTERNAL_READ_GAS,
            _EXECUTOR_CONFIRM_CALL_GAS
        );
        _configurationHash = keccak256(bytes.concat(configurationIdentity, configurationPolicy));
        _daoProposer = _requireExecutorConfig();
    }

    /// @inheritdoc IComponentConfigV2
    function componentConfigHashV2() external view returns (bytes32 configHash_) {
        return _configurationHash;
    }

    /// @inheritdoc IProtocolRootFactoryV1
    function protocolRootFactoryConfigV1()
        external
        view
        returns (ProtocolRootFactoryConfigV1 memory)
    {
        uint256 settlementChainId = _settlementChainId;
        bytes32 manifestNamespace = _manifestNamespace;
        address delayedExecutor = _delayedExecutor;
        bytes32 executorRuntimeHash = _executorRuntimeHash;
        bytes32 executorConfigurationHash = _executorConfigurationHash;
        bytes32 proxyCreationCodeHash = _proxyCreationCodeHash;
        bytes32 proxyRuntimeHash = _proxyRuntimeHash;
        bytes32 configurationHash = _configurationHash;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, shl(224, 0x50524631))
            mstore(add(ptr, 32), settlementChainId)
            mstore(add(ptr, 64), manifestNamespace)
            mstore(add(ptr, 96), delayedExecutor)
            mstore(add(ptr, 128), executorRuntimeHash)
            mstore(add(ptr, 160), executorConfigurationHash)
            mstore(add(ptr, 192), proxyCreationCodeHash)
            mstore(add(ptr, 224), proxyRuntimeHash)
            mstore(add(ptr, 256), 2592000)
            mstore(add(ptr, 288), 500000)
            mstore(add(ptr, 320), 18)
            mstore(add(ptr, 352), 100000)
            mstore(add(ptr, 384), 50000)
            mstore(add(ptr, 416), 50000)
            mstore(add(ptr, 448), 100000)
            mstore(add(ptr, 480), 500000)
            mstore(add(ptr, 512), configurationHash)
            return(ptr, 544)
        }
    }

    /// @inheritdoc IProtocolRootFactoryV1
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
        )
    {
        Campaign memory campaign = _campaigns[_campaignKey];
        return (
            _PRC1_MAGIC,
            campaign.operationId,
            campaign.key,
            campaign.manifestHash,
            campaign.state,
            campaign.generation,
            campaign.expiresAt,
            campaign.deployedBitmap,
            campaign.rootReceipt
        );
    }

    /// @inheritdoc IProtocolRootFactoryV1
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
        )
    {
        Campaign storage campaign = _campaigns[_campaignKey];
        if (campaign.state == _CAMPAIGN_NONE || _role == 0 || _role > 9) {
            return (_PRD1_MAGIC, bytes32(0), 0, address(0), bytes32(0), bytes32(0), bytes32(0));
        }
        ComponentDescriptor storage descriptor = _components[_campaignKey][_role];
        return (
            _PRD1_MAGIC,
            _campaignKey,
            _role,
            _componentAddress(_campaignKey, _role),
            descriptor.initCodeHash,
            descriptor.runtimeHash,
            descriptor.configurationHash
        );
    }

    /// @inheritdoc IProtocolRootFactoryV1
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
        )
    {
        _requireCanonicalStageCalldata(_manifest);
        if (msg.sender != _delayedExecutor || _operationId == bytes32(0)) {
            revert UnauthorizedRootMigrationExecutor();
        }
        if (_liveCampaignKey != bytes32(0) || _activeRootReceipt != bytes32(0)) {
            revert FactoryAlreadyHasRootOrCampaign();
        }
        StageContext memory context = _prepareStage(_operationId, _manifest);
        _storeStagedCampaign(_operationId, _manifest, context);
        return (
            _STG1_MAGIC,
            _operationId,
            context.campaignKey,
            context.manifestHash,
            context.generation,
            context.expiresAt
        );
    }

    /// @inheritdoc IProtocolRootFactoryV1
    function deployProtocolRootComponentV1(
        bytes32 _campaignKeyValue,
        uint8 _role,
        bytes calldata _initCode
    )
        external
        returns (address component_)
    {
        _requireCanonicalDeployCalldata(_role, _initCode);
        Campaign storage campaign = _campaigns[_campaignKeyValue];
        if (
            campaign.state != _CAMPAIGN_STAGED || _liveCampaignKey != _campaignKeyValue
                || block.timestamp > campaign.expiresAt || _role == 0 || _role > 9
                || (campaign.deployedBitmap & (uint16(1) << (_role - 1))) != 0
        ) {
            revert ProtocolRootComponentNotDeployable();
        }
        ComponentDescriptor storage descriptor = _components[_campaignKeyValue][_role];
        if (
            _initCode.length == 0 || _initCode.length > 49_152
                || keccak256(_initCode) != descriptor.initCodeHash
        ) {
            revert ProtocolRootInitCodeMismatch();
        }

        bytes32 salt = _componentSalt(_campaignKeyValue, _role);
        address expectedProxy = _proxyAddress(salt);
        ProtocolRootCreate3ProxyV1 proxy = new ProtocolRootCreate3ProxyV1{ salt: salt }();
        if (address(proxy) != expectedProxy) revert ProtocolRootProxyAddressMismatch();
        LibRootBootstrapV1.requireRuntime(expectedProxy, _proxyRuntimeHash);

        bytes memory raw = LibRootBootstrapV1.callCreate3ProxyExact(
            expectedProxy,
            abi.encodeWithSelector(ProtocolRootCreate3ProxyV1.deployV1.selector, _initCode),
            32
        );
        component_ = LibRootBootstrapV1.addressWord(raw, 0);
        if (component_ != _componentAddress(_campaignKeyValue, _role)) {
            revert ProtocolRootComponentAddressMismatch();
        }
        LibRootBootstrapV1.requireRuntime(component_, descriptor.runtimeHash);
        LibRootBootstrapV1.requireConfiguration(
            component_, descriptor.configurationHash, _COMPONENT_CONFIG_READ_GAS
        );
        _requireActivationState(component_, _campaignKeyValue, 0);

        descriptor.component = component_;
        campaign.deployedBitmap |= uint16(1) << (_role - 1);
        emit ProtocolRootComponentDeployed(
            _campaignKeyValue, campaign.generation, _role, component_
        );
    }

    /// @inheritdoc IProtocolRootFactoryV1
    function finalizeProtocolRootV1(bytes32 _campaignKeyValue)
        external
        returns (bytes32 rootReceipt_)
    {
        if (msg.data.length != 36) revert NonCanonicalFactoryCalldata();
        Campaign storage campaign = _campaigns[_campaignKeyValue];
        if (
            campaign.state != _CAMPAIGN_STAGED || _liveCampaignKey != _campaignKeyValue
                || _activeRootReceipt != bytes32(0) || block.timestamp > campaign.expiresAt
                || campaign.deployedBitmap != _ALL_ROLES_BITMAP
        ) {
            revert ProtocolRootNotFinalizable();
        }

        address[9] memory components;
        for (uint8 role = 1; role <= 9; ++role) {
            ComponentDescriptor storage descriptor = _components[_campaignKeyValue][role];
            address component = _componentAddress(_campaignKeyValue, role);
            if (descriptor.component != component) revert ProtocolRootComponentAddressMismatch();
            LibRootBootstrapV1.requireRuntime(component, descriptor.runtimeHash);
            LibRootBootstrapV1.requireConfiguration(
                component, descriptor.configurationHash, _COMPONENT_CONFIG_READ_GAS
            );
            _requireActivationState(component, _campaignKeyValue, 0);
            components[role - 1] = component;
        }

        (uint64 genesisTimestamp, uint64 firstManagedWindow) =
            _validateComponentGraph(_campaignKeyValue, components);
        uint256 currentWindow =
            block.timestamp < genesisTimestamp ? 0 : (block.timestamp - genesisTimestamp) / 384;
        if (
            firstManagedWindow == type(uint64).max
                || currentWindow > type(uint64).max - _MINIMUM_FIRST_MANAGED_RUNWAY_WINDOWS
                || firstManagedWindow < currentWindow + _MINIMUM_FIRST_MANAGED_RUNWAY_WINDOWS
        ) {
            revert InsufficientFirstManagedWindowRunway();
        }

        for (uint8 role = 1; role <= 9; ++role) {
            bytes memory activated = LibRootBootstrapV1.callExact(
                components[role - 1],
                abi.encodeWithSelector(_ACTIVATE_SELECTOR, _campaignKeyValue),
                _ACTIVATION_CALL_GAS,
                32,
                0
            );
            if (LibRootBootstrapV1.word(activated, 0) != bytes32(_RAA1_MAGIC)) {
                revert ProtocolRootActivationFailed(role);
            }
            _requireActivationState(components[role - 1], _campaignKeyValue, 1);
        }

        bytes memory receiptHead = abi.encodePacked(
            "slot-chain-protocol-root-receipt-v1",
            _campaignKeyValue,
            campaign.manifestHash,
            components[0],
            components[1],
            components[2],
            components[3]
        );
        bytes memory receiptTail = abi.encodePacked(
            components[4], components[5], components[6], components[7], components[8]
        );
        rootReceipt_ = keccak256(bytes.concat(receiptHead, receiptTail));
        campaign.state = _CAMPAIGN_ACTIVE;
        campaign.rootReceipt = rootReceipt_;
        _activeRootReceipt = rootReceipt_;

        LibRootBootstrapV1.requireRuntime(_delayedExecutor, _executorRuntimeHash);
        LibRootBootstrapV1.requireConfiguration(
            _delayedExecutor, _executorConfigurationHash, _COMPONENT_CONFIG_READ_GAS
        );
        bytes memory confirmation = LibRootBootstrapV1.callExact(
            _delayedExecutor,
            abi.encodeWithSelector(
                _EXECUTOR_CONFIRM_SELECTOR, campaign.operationId, _campaignKeyValue, rootReceipt_
            ),
            _EXECUTOR_CONFIRM_CALL_GAS,
            32,
            0
        );
        if (LibRootBootstrapV1.word(confirmation, 0) != bytes32(_RAC1_MAGIC)) {
            revert InvalidExecutorConfirmation();
        }

        _nextGeneration = campaign.generation + 1;
        delete _liveCampaignKey;
        emit ProtocolRootActivated(_campaignKeyValue, rootReceipt_, campaign.generation);
    }

    /// @inheritdoc IProtocolRootFactoryV1
    function abortProtocolRootCampaignV1(bytes32 _campaignKeyValue) external {
        if (msg.data.length != 36) revert NonCanonicalFactoryCalldata();
        Campaign storage campaign = _campaigns[_campaignKeyValue];
        if (
            campaign.state != _CAMPAIGN_STAGED || _liveCampaignKey != _campaignKeyValue
                || block.timestamp <= campaign.expiresAt
        ) {
            revert ProtocolRootCampaignNotAbortable();
        }
        campaign.state = _CAMPAIGN_ABORTED;
        _nextGeneration = campaign.generation + 1;
        delete _liveCampaignKey;
        emit ProtocolRootCampaignAborted(_campaignKeyValue, campaign.generation);
    }

    /// @dev Validates and derives one stage context without retaining scalar stack state.
    function _prepareStage(
        bytes32 _operationId,
        bytes calldata _manifest
    )
        private
        view
        returns (StageContext memory context_)
    {
        context_.generation = _nextGeneration;
        if (context_.generation == type(uint64).max) revert ProtocolRootGenerationExhausted();
        (uint64 manifestGeneration, bytes32 namespace, bytes32 predecessor) =
            _validateManifestHeader(_manifest);
        if (
            manifestGeneration != context_.generation || namespace != _manifestNamespace
                || predecessor != bytes32(0)
        ) {
            revert InvalidProtocolRootManifest();
        }
        context_.campaignKey = _campaignKey(context_.generation, predecessor);
        context_.manifestHash = _manifestHash(_manifest);
        _requireExecutorCandidate(_operationId, context_.campaignKey);
        if (block.timestamp > type(uint64).max - _CAMPAIGN_LIFETIME) {
            revert ProtocolRootCampaignTimestampOverflow();
        }
        context_.expiresAt = uint64(block.timestamp) + _CAMPAIGN_LIFETIME;
    }

    /// @dev Stores one already validated stage context and its nine component descriptors.
    function _storeStagedCampaign(
        bytes32 _operationId,
        bytes calldata _manifest,
        StageContext memory _context
    )
        private
    {
        Campaign storage campaign = _campaigns[_context.campaignKey];
        if (campaign.state != _CAMPAIGN_NONE) revert ProtocolRootCampaignExists();
        campaign.operationId = _operationId;
        campaign.key = _context.campaignKey;
        campaign.manifestHash = _context.manifestHash;
        campaign.state = _CAMPAIGN_STAGED;
        campaign.generation = _context.generation;
        campaign.expiresAt = _context.expiresAt;
        _storeManifestComponents(_context.campaignKey, _manifest);
        _liveCampaignKey = _context.campaignKey;
        emit ProtocolRootCampaignStaged(
            _context.campaignKey,
            _context.manifestHash,
            _context.generation,
            _operationId,
            _context.expiresAt
        );
    }

    /// @dev Stores the nine exact nonzero component commitment triples from packed calldata.
    function _storeManifestComponents(
        bytes32 _campaignKeyValue,
        bytes calldata _manifest
    )
        private
    {
        for (uint8 role = 1; role <= 9; ++role) {
            uint256 offset = 105 + uint256(role - 1) * 96;
            bytes32 initCodeHash;
            bytes32 runtimeHash;
            bytes32 configHash;
            assembly ("memory-safe") {
                initCodeHash := calldataload(add(_manifest.offset, offset))
                runtimeHash := calldataload(add(add(_manifest.offset, offset), 32))
                configHash := calldataload(add(add(_manifest.offset, offset), 64))
            }
            if (initCodeHash == bytes32(0) || runtimeHash == bytes32(0) || configHash == bytes32(0))
            {
                revert InvalidProtocolRootManifest();
            }
            _components[_campaignKeyValue][role] = ComponentDescriptor({
                component: address(0),
                initCodeHash: initCodeHash,
                runtimeHash: runtimeHash,
                configurationHash: configHash
            });
        }
    }

    /// @dev Validates the exact BRC1/SOC1/PVM1 graph and returns its launch clocks.
    function _validateComponentGraph(
        bytes32 _campaignKeyValue,
        address[9] memory _component
    )
        private
        view
        returns (uint64 genesisTimestamp_, uint64 firstManagedWindow_)
    {
        {
            bytes memory pvm = LibRootBootstrapV1.staticcallExact(
                _component[3], abi.encodeWithSelector(_PVM1_SELECTOR), _EXTERNAL_READ_GAS, 1088
            );
            LibRootBootstrapV1.requireMagic(pvm, _PVM1_MAGIC);
            _validateProtocolVersionManagerPolicy(pvm);
            {
                bytes memory pct = LibRootBootstrapV1.staticcallExact(
                    _component[2], abi.encodeWithSelector(_PCT1_SELECTOR), _EXTERNAL_READ_GAS, 160
                );
                LibRootBootstrapV1.requireMagic(pct, _PCT1_MAGIC);
                _validateTimelockRootJoin(_campaignKeyValue, _component, pct, pvm);
            }
            _validatePvmRootJoin(_campaignKeyValue, _component, pvm);
        }
        bytes memory brc = LibRootBootstrapV1.staticcallExact(
            _component[0], abi.encodeWithSelector(_BRC1_SELECTOR), _EXTERNAL_READ_GAS, 672
        );
        bytes memory soc = LibRootBootstrapV1.staticcallExact(
            _component[1], abi.encodeWithSelector(_SOC1_SELECTOR), _EXTERNAL_READ_GAS, 416
        );
        LibRootBootstrapV1.requireMagic(brc, _BRC1_MAGIC);
        LibRootBootstrapV1.requireMagic(soc, _SOC1_MAGIC);
        uint192 lease = _validateBuilderRegistryPolicy(brc);
        uint64 beaconGenesisTime = _validateScheduleOraclePolicy(soc);

        ComponentDescriptor storage registry = _components[_campaignKeyValue][1];
        ComponentDescriptor storage schedule = _components[_campaignKeyValue][2];
        ComponentDescriptor storage router = _components[_campaignKeyValue][5];
        if (
            uint256(LibRootBootstrapV1.word(brc, 1)) != _settlementChainId
                || LibRootBootstrapV1.word(brc, 19) != registry.configurationHash
                || LibRootBootstrapV1.addressWord(brc, 14) != _component[4]
                || LibRootBootstrapV1.word(brc, 15) != router.runtimeHash
                || LibRootBootstrapV1.word(brc, 16) != router.configurationHash
                || LibRootBootstrapV1.addressWord(brc, 17) != _component[1]
                || LibRootBootstrapV1.word(brc, 18) != schedule.runtimeHash
        ) {
            revert InvalidBuilderRegistryRootJoin();
        }
        bytes32 topologyHash = _builderTopologyHash(brc);
        if (LibRootBootstrapV1.word(brc, 20) != topologyHash) {
            revert InvalidBuilderRegistryRootJoin();
        }

        genesisTimestamp_ = LibRootBootstrapV1.u64Word(brc, 8);
        firstManagedWindow_ = LibRootBootstrapV1.u64Word(brc, 11);
        uint256 firstManagedWindowStart =
            uint256(genesisTimestamp_) + uint256(firstManagedWindow_) * 384;
        if (
            firstManagedWindowStart < 768
                || firstManagedWindowStart < uint256(beaconGenesisTime) + 3072
        ) {
            revert InvalidScheduleOracleRootJoin();
        }
        if (
            uint256(LibRootBootstrapV1.word(soc, 1)) != _settlementChainId
                || LibRootBootstrapV1.addressWord(soc, 2) != _component[3]
                || LibRootBootstrapV1.addressWord(soc, 3) != _component[4]
                || LibRootBootstrapV1.addressWord(soc, 4) != _component[0]
                || LibRootBootstrapV1.u64Word(soc, 5) != firstManagedWindow_
                || LibRootBootstrapV1.u64Word(soc, 6) != genesisTimestamp_
                || uint256(LibRootBootstrapV1.word(soc, 9)) != lease
                || LibRootBootstrapV1.word(soc, 11) != topologyHash
                || LibRootBootstrapV1.word(soc, 12) != schedule.configurationHash
        ) {
            revert InvalidScheduleOracleRootJoin();
        }
        bytes32 forkWord = LibRootBootstrapV1.word(soc, 10);
        if (forkWord == bytes32(0) || forkWord != bytes32(bytes4(forkWord))) {
            revert InvalidScheduleOracleRootJoin();
        }
    }

    /// @dev Recomputes role 3's live governance descriptor and joins it to PVM1 word 12.
    function _validateTimelockRootJoin(
        bytes32 _campaignKeyValue,
        address[9] memory _component,
        bytes memory _pct,
        bytes memory _pvm
    )
        private
        view
    {
        address daoProposer = LibRootBootstrapV1.addressWord(_pct, 1);
        if (
            daoProposer != _daoProposer || daoProposer == address(this)
                || daoProposer == _delayedExecutor
                || LibRootBootstrapV1.addressWord(_pct, 2) != _component[3]
                || LibRootBootstrapV1.u64Word(_pct, 3) != 604_800
                || LibRootBootstrapV1.word(_pct, 4) != _PROTOCOL_CHANGE_OPERATION_DOMAIN
        ) {
            revert InvalidProtocolChangeTimelockRootJoin();
        }
        for (uint256 i; i < 9; ++i) {
            if (daoProposer == _component[i]) revert InvalidProtocolChangeTimelockRootJoin();
        }
        ComponentDescriptor storage timelock = _components[_campaignKeyValue][3];
        bytes32 descriptorHash = keccak256(
            abi.encodePacked(
                "slot-chain-protocol-change-timelock-v1",
                _settlementChainId,
                _component[2],
                timelock.runtimeHash,
                daoProposer,
                _component[3],
                uint64(604_800),
                _PROTOCOL_CHANGE_OPERATION_DOMAIN
            )
        );
        if (
            timelock.configurationHash != descriptorHash
                || LibRootBootstrapV1.word(_pvm, 12) != descriptorHash
        ) {
            revert InvalidProtocolChangeTimelockRootJoin();
        }
    }

    /// @dev Strictly joins PVM1 addresses/runtime/configuration pairs and recomputes its hash.
    function _validatePvmRootJoin(
        bytes32 _campaignKeyValue,
        address[9] memory _component,
        bytes memory _pvm
    )
        private
        view
    {
        uint8[8] memory addressWords = [uint8(2), 3, 4, 5, 6, 7, 10, 11];
        uint8[8] memory roles = [uint8(3), 5, 6, 1, 2, 7, 8, 9];
        for (uint256 i; i < 8; ++i) {
            if (LibRootBootstrapV1.addressWord(_pvm, addressWords[i]) != _component[roles[i] - 1]) {
                revert InvalidProtocolVersionManagerRootJoin();
            }
        }
        if (
            uint256(LibRootBootstrapV1.word(_pvm, 1)) != _settlementChainId
                || LibRootBootstrapV1.word(_pvm, 12)
                    != _components[_campaignKeyValue][3].configurationHash
                || LibRootBootstrapV1.word(_pvm, 13) != _manifestNamespace
        ) {
            revert InvalidProtocolVersionManagerRootJoin();
        }
        uint8[6] memory pairWords = [uint8(22), 24, 26, 28, 30, 32];
        uint8[6] memory pairRoles = [uint8(5), 6, 1, 2, 8, 9];
        for (uint256 i; i < 6; ++i) {
            ComponentDescriptor storage descriptor = _components[_campaignKeyValue][pairRoles[i]];
            if (
                LibRootBootstrapV1.word(_pvm, pairWords[i]) != descriptor.runtimeHash
                    || LibRootBootstrapV1.word(_pvm, pairWords[i] + 1)
                        != descriptor.configurationHash
            ) {
                revert InvalidProtocolVersionManagerRootJoin();
            }
        }
        ComponentDescriptor storage market = _components[_campaignKeyValue][7];
        if (
            LibRootBootstrapV1.word(_pvm, 8) != market.runtimeHash
                || LibRootBootstrapV1.word(_pvm, 9) != market.configurationHash
                || _protocolVersionManagerHash(_pvm)
                    != _components[_campaignKeyValue][4].configurationHash
        ) {
            revert InvalidProtocolVersionManagerRootJoin();
        }
    }

    /// @dev Canonically decodes and validates the BRC1 scalar policy row used by the root join.
    function _validateBuilderRegistryPolicy(bytes memory _brc)
        private
        pure
        returns (uint192 lease_)
    {
        if (LibRootBootstrapV1.word(_brc, 3) == bytes32(0)) {
            revert InvalidBuilderRegistryRootJoin();
        }
        lease_ = LibRootBootstrapV1.u192Word(_brc, 5);
        uint192 maximumBond = LibRootBootstrapV1.u192Word(_brc, 6);
        uint192 reporterRewardCap = LibRootBootstrapV1.u192Word(_brc, 7);
        if (lease_ == 0 || lease_ > maximumBond || uint256(reporterRewardCap) * 5 > lease_) {
            revert InvalidBuilderRegistryRootJoin();
        }
    }

    /// @dev Canonically decodes the SOC1 clocks and enforces the frozen lookahead.
    function _validateScheduleOraclePolicy(bytes memory _soc)
        private
        pure
        returns (uint64 beaconGenesisTime_)
    {
        beaconGenesisTime_ = LibRootBootstrapV1.u64Word(_soc, 7);
        if (LibRootBootstrapV1.u64Word(_soc, 8) != 768) revert InvalidScheduleOracleRootJoin();
    }

    /// @dev Enforces the frozen PVM1 governance clocks and nonzero release gas certificate.
    function _validateProtocolVersionManagerPolicy(bytes memory _pvm) private pure {
        if (
            LibRootBootstrapV1.u64Word(_pvm, 14) != 604_800
                || LibRootBootstrapV1.u64Word(_pvm, 15) != 604_800
                || LibRootBootstrapV1.u64Word(_pvm, 16) != 604_800
                || LibRootBootstrapV1.u16Word(_pvm, 17) != 64
                || LibRootBootstrapV1.u64Word(_pvm, 18) == 0
                || LibRootBootstrapV1.u64Word(_pvm, 19) == 0
                || LibRootBootstrapV1.u64Word(_pvm, 20) == 0
                || LibRootBootstrapV1.u64Word(_pvm, 21) == 0
        ) {
            revert InvalidProtocolVersionManagerRootJoin();
        }
    }

    /// @dev Recomputes the exact 313-byte BuilderRegistry topology preimage.
    function _builderTopologyHash(bytes memory _brc) private pure returns (bytes32 hash_) {
        bytes memory head = abi.encodePacked(
            uint256(LibRootBootstrapV1.word(_brc, 1)),
            LibRootBootstrapV1.addressWord(_brc, 2),
            LibRootBootstrapV1.word(_brc, 3),
            LibRootBootstrapV1.u8Word(_brc, 4),
            LibRootBootstrapV1.u64Word(_brc, 8),
            LibRootBootstrapV1.u64Word(_brc, 9),
            LibRootBootstrapV1.u64Word(_brc, 10),
            LibRootBootstrapV1.u64Word(_brc, 11)
        );
        bytes memory tail = abi.encodePacked(
            LibRootBootstrapV1.addressWord(_brc, 12),
            LibRootBootstrapV1.u64Word(_brc, 13),
            LibRootBootstrapV1.addressWord(_brc, 14),
            LibRootBootstrapV1.word(_brc, 15),
            LibRootBootstrapV1.word(_brc, 16),
            LibRootBootstrapV1.addressWord(_brc, 17),
            LibRootBootstrapV1.word(_brc, 18),
            LibRootBootstrapV1.word(_brc, 19)
        );
        if (head.length != 117 || tail.length != 196) revert InvalidBuilderRegistryRootJoin();
        return keccak256(
            bytes.concat("slot-chain-builder-registry-topology-v1", bytes2(uint16(313)), head, tail)
        );
    }

    /// @dev Recomputes PVM configuration from its exact decoded PVM1 row.
    function _protocolVersionManagerHash(bytes memory _pvm) private pure returns (bytes32 hash_) {
        bytes memory identities = abi.encodePacked(
            "slot-chain-protocol-version-manager-config-v1",
            uint256(LibRootBootstrapV1.word(_pvm, 1)),
            LibRootBootstrapV1.addressWord(_pvm, 2),
            LibRootBootstrapV1.word(_pvm, 12),
            LibRootBootstrapV1.addressWord(_pvm, 3),
            LibRootBootstrapV1.word(_pvm, 22),
            LibRootBootstrapV1.word(_pvm, 23),
            LibRootBootstrapV1.addressWord(_pvm, 4),
            LibRootBootstrapV1.word(_pvm, 24),
            LibRootBootstrapV1.word(_pvm, 25)
        );
        bytes memory controlsA = abi.encodePacked(
            LibRootBootstrapV1.addressWord(_pvm, 5),
            LibRootBootstrapV1.word(_pvm, 26),
            LibRootBootstrapV1.word(_pvm, 27),
            LibRootBootstrapV1.addressWord(_pvm, 6),
            LibRootBootstrapV1.word(_pvm, 28),
            LibRootBootstrapV1.word(_pvm, 29)
        );
        bytes memory controlsB = abi.encodePacked(
            LibRootBootstrapV1.addressWord(_pvm, 7),
            LibRootBootstrapV1.word(_pvm, 8),
            LibRootBootstrapV1.word(_pvm, 9),
            LibRootBootstrapV1.addressWord(_pvm, 10),
            LibRootBootstrapV1.word(_pvm, 30),
            LibRootBootstrapV1.word(_pvm, 31)
        );
        bytes memory controlsC = abi.encodePacked(
            LibRootBootstrapV1.addressWord(_pvm, 11),
            LibRootBootstrapV1.word(_pvm, 32),
            LibRootBootstrapV1.word(_pvm, 33)
        );
        bytes memory policy = abi.encodePacked(
            LibRootBootstrapV1.word(_pvm, 13),
            LibRootBootstrapV1.u64Word(_pvm, 14),
            LibRootBootstrapV1.u64Word(_pvm, 15),
            LibRootBootstrapV1.u64Word(_pvm, 16),
            LibRootBootstrapV1.u16Word(_pvm, 17),
            LibRootBootstrapV1.u64Word(_pvm, 18),
            LibRootBootstrapV1.u64Word(_pvm, 19),
            LibRootBootstrapV1.u64Word(_pvm, 20),
            LibRootBootstrapV1.u64Word(_pvm, 21)
        );
        return keccak256(bytes.concat(identities, controlsA, controlsB, controlsC, policy));
    }

    /// @dev Requires exact Executor runtime/configuration and the frozen RME1 row.
    function _requireExecutorConfig() private view returns (address daoProposer_) {
        LibRootBootstrapV1.requireRuntime(_delayedExecutor, _executorRuntimeHash);
        LibRootBootstrapV1.requireConfiguration(
            _delayedExecutor, _executorConfigurationHash, _COMPONENT_CONFIG_READ_GAS
        );
        bytes memory raw = LibRootBootstrapV1.staticcallExact(
            _delayedExecutor,
            abi.encodeWithSelector(_EXECUTOR_CONFIG_SELECTOR),
            _EXECUTOR_CONFIG_READ_GAS,
            320
        );
        LibRootBootstrapV1.requireMagic(raw, _RME1_MAGIC);
        daoProposer_ = LibRootBootstrapV1.addressWord(raw, 2);
        if (
            uint256(LibRootBootstrapV1.word(raw, 1)) != _settlementChainId
                || LibRootBootstrapV1.u64Word(raw, 3) != 604_800
                || LibRootBootstrapV1.u64Word(raw, 4) != 604_800
                || LibRootBootstrapV1.u64Word(raw, 5) != 100_000
                || LibRootBootstrapV1.u64Word(raw, 6) != 50_000
                || LibRootBootstrapV1.u64Word(raw, 7) != 1_500_000
                || LibRootBootstrapV1.u64Word(raw, 8) != 300_000
                || LibRootBootstrapV1.word(raw, 9) != _executorConfigurationHash
        ) {
            revert InvalidExecutorConfiguration();
        }
    }

    /// @dev Requires this Factory to be the sole Executor CANDIDATE for operation/key.
    function _requireExecutorCandidate(
        bytes32 _operationId,
        bytes32 _campaignKeyValue
    )
        private
        view
    {
        if (_requireExecutorConfig() != _daoProposer) revert InvalidExecutorConfiguration();
        bytes memory raw = LibRootBootstrapV1.staticcallExact(
            _delayedExecutor,
            abi.encodeWithSelector(_EXECUTOR_AUTHORITY_SELECTOR),
            _EXECUTOR_CONFIG_READ_GAS,
            288
        );
        LibRootBootstrapV1.requireMagic(raw, _RMA1_MAGIC);
        if (
            LibRootBootstrapV1.u8Word(raw, 1) != 1
                || LibRootBootstrapV1.addressWord(raw, 2) != address(this)
                || LibRootBootstrapV1.word(raw, 3) != _operationId
                || LibRootBootstrapV1.word(raw, 4) != _campaignKeyValue
                || LibRootBootstrapV1.word(raw, 5) != bytes32(0)
                || LibRootBootstrapV1.word(raw, 6) != bytes32(0)
                || LibRootBootstrapV1.word(raw, 7) != bytes32(0)
                || LibRootBootstrapV1.word(raw, 8) != bytes32(0)
        ) {
            revert InvalidExecutorCandidate();
        }
    }

    /// @dev Requires one exact PRA1 state bound to this Factory and campaign.
    function _requireActivationState(
        address _component,
        bytes32 _campaignKeyValue,
        uint8 _state
    )
        private
        view
    {
        bytes memory raw = LibRootBootstrapV1.staticcallExact(
            _component, abi.encodeWithSelector(_ACTIVATION_VIEW_SELECTOR), _EXTERNAL_READ_GAS, 128
        );
        LibRootBootstrapV1.requireMagic(raw, _PRA1_MAGIC);
        if (
            LibRootBootstrapV1.addressWord(raw, 1) != address(this)
                || LibRootBootstrapV1.word(raw, 2) != _campaignKeyValue
                || LibRootBootstrapV1.u8Word(raw, 3) != _state
        ) {
            revert InvalidProtocolRootActivationState();
        }
    }

    /// @dev Parses the fixed manifest header after exact outer ABI validation.
    function _validateManifestHeader(bytes calldata _manifest)
        private
        view
        returns (uint64 generation_, bytes32 namespace_, bytes32 predecessor_)
    {
        uint8 schema;
        uint256 chainId;
        assembly ("memory-safe") {
            schema := byte(0, calldataload(_manifest.offset))
            chainId := calldataload(add(_manifest.offset, 1))
            generation_ := shr(192, calldataload(add(_manifest.offset, 33)))
            namespace_ := calldataload(add(_manifest.offset, 41))
            predecessor_ := calldataload(add(_manifest.offset, 73))
        }
        if (schema != 1 || chainId != _settlementChainId || namespace_ == bytes32(0)) {
            revert InvalidProtocolRootManifest();
        }
    }

    /// @dev Enforces canonical stage ABI: 0x40 offset, exact 969-byte tail and zero padding.
    function _requireCanonicalStageCalldata(bytes calldata _manifest) private pure {
        uint256 dynamicOffset;
        uint256 dynamicLength;
        assembly ("memory-safe") {
            dynamicOffset := calldataload(36)
            dynamicLength := calldataload(68)
        }
        if (
            dynamicOffset != 64 || dynamicLength != 969 || _manifest.length != 969
                || msg.data.length != 1092 || !_hasZeroManifestPadding(_manifest)
        ) {
            revert NonCanonicalFactoryCalldata();
        }
    }

    /// @dev Enforces canonical deploy ABI before CREATE2 or any state read with side effects.
    function _requireCanonicalDeployCalldata(
        uint8 _role,
        bytes calldata _initCode
    )
        private
        pure
    {
        uint256 roleWord;
        uint256 dynamicOffset;
        uint256 dynamicLength;
        assembly ("memory-safe") {
            roleWord := calldataload(36)
            dynamicOffset := calldataload(68)
            dynamicLength := calldataload(100)
        }
        uint256 padded = (dynamicLength + 31) & ~uint256(31);
        if (
            roleWord != _role || roleWord > type(uint8).max || dynamicOffset != 96
                || dynamicLength != _initCode.length || dynamicLength == 0 || dynamicLength > 49_152
                || msg.data.length != 132 + padded
        ) {
            revert NonCanonicalFactoryCalldata();
        }
        uint256 remainder = dynamicLength & 31;
        if (remainder != 0) {
            uint256 finalWord;
            assembly ("memory-safe") {
                finalWord := calldataload(add(_initCode.offset, sub(dynamicLength, remainder)))
            }
            if ((finalWord & ((uint256(1) << ((32 - remainder) * 8)) - 1)) != 0) {
                revert NonCanonicalFactoryCalldata();
            }
        }
    }

    /// @dev Checks the manifest's 23-byte final ABI padding.
    function _hasZeroManifestPadding(bytes calldata _manifest) private pure returns (bool zero_) {
        uint256 finalWord;
        assembly ("memory-safe") {
            finalWord := calldataload(add(_manifest.offset, 960))
        }
        return (finalWord & ((uint256(1) << 184) - 1)) == 0;
    }

    /// @dev Derives the exact manifest commitment.
    function _manifestHash(bytes calldata _manifest) private pure returns (bytes32 hash_) {
        return keccak256(
            abi.encodePacked("slot-chain-protocol-root-manifest-v1", uint16(969), _manifest)
        );
    }

    /// @dev Derives the code-independent campaign key.
    function _campaignKey(
        uint64 _generation,
        bytes32 _predecessor
    )
        private
        view
        returns (bytes32 key_)
    {
        return keccak256(
            abi.encodePacked(
                "slot-chain-protocol-root-campaign-v1",
                _settlementChainId,
                address(this),
                _generation,
                _manifestNamespace,
                _predecessor
            )
        );
    }

    /// @dev Derives one fixed CREATE2 proxy salt.
    function _componentSalt(
        bytes32 _campaignKeyValue,
        uint8 _role
    )
        private
        pure
        returns (bytes32 salt_)
    {
        return keccak256(
            abi.encodePacked("slot-chain-protocol-root-component-v1", _campaignKeyValue, _role)
        );
    }

    /// @dev Derives one CREATE2 proxy address.
    function _proxyAddress(bytes32 _salt) private view returns (address proxy_) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), address(this), _salt, _proxyCreationCodeHash)
                    )
                )
            )
        );
    }

    /// @dev Derives one proxy nonce-one child address.
    function _componentAddress(
        bytes32 _campaignKeyValue,
        uint8 _role
    )
        private
        view
        returns (address component_)
    {
        address proxy = _proxyAddress(_componentSalt(_campaignKeyValue, _role));
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", proxy, hex"01")))));
    }

    error FactoryAlreadyHasRootOrCampaign();
    error InsufficientFirstManagedWindowRunway();
    error InvalidBuilderRegistryRootJoin();
    error InvalidExecutorCandidate();
    error InvalidExecutorConfiguration();
    error InvalidExecutorConfirmation();
    error InvalidFactoryConfiguration();
    error InvalidProtocolRootActivationState();
    error InvalidProtocolRootManifest();
    error InvalidProtocolChangeTimelockRootJoin();
    error InvalidProtocolVersionManagerRootJoin();
    error InvalidScheduleOracleRootJoin();
    error NonCanonicalFactoryCalldata();
    error ProtocolRootActivationFailed(uint8 role);
    error ProtocolRootCampaignExists();
    error ProtocolRootCampaignNotAbortable();
    error ProtocolRootCampaignTimestampOverflow();
    error ProtocolRootComponentAddressMismatch();
    error ProtocolRootComponentNotDeployable();
    error ProtocolRootGenerationExhausted();
    error ProtocolRootInitCodeMismatch();
    error ProtocolRootNotFinalizable();
    error ProtocolRootProxyAddressMismatch();
    error UnauthorizedRootMigrationExecutor();
}
