// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    ProtocolRootCreate3ProxyV1
} from "../../../../contracts/layer1/slotchain/root/ProtocolRootCreate3ProxyV1.sol";
import {
    ProtocolRootFactoryV1
} from "../../../../contracts/layer1/slotchain/root/ProtocolRootFactoryV1.sol";
import {
    RootMigrationExecutorV1
} from "../../../../contracts/layer1/slotchain/root/RootMigrationExecutorV1.sol";
import {
    IProtocolRootFactoryV1
} from "../../../../contracts/layer1/slotchain/root/iface/IProtocolRootFactoryV1.sol";
import {
    LibRootBootstrapV1
} from "../../../../contracts/layer1/slotchain/root/libs/LibRootBootstrapV1.sol";
import { Test } from "forge-std/src/Test.sol";

contract RootDeployGate {
    bool public allowDeploy = true;

    function setAllowed(bool _allowed) external {
        allowDeploy = _allowed;
    }
}

contract FactoryRoleMock {
    bytes4 private constant _PRA1 = 0x50524131;
    bytes4 private constant _RAA1 = 0x52414131;

    address private _factory;
    bytes32 private _campaignKey;
    bytes32 private _configurationHash;
    bytes4 private _rootViewSelector;
    bytes private _rootView;
    uint8 private _activationState;
    bool private _failActivation;

    constructor(
        address _factoryAddress,
        bytes32 _key,
        bytes32 _configHash,
        bytes4 _selector,
        bytes memory _response,
        RootDeployGate _gate,
        bool _activationMustFail
    ) {
        if (!_gate.allowDeploy()) revert DeploymentClosed();
        _factory = _factoryAddress;
        _campaignKey = _key;
        _configurationHash = _configHash;
        _rootViewSelector = _selector;
        _rootView = _response;
        _failActivation = _activationMustFail;
    }

    function componentConfigHashV2() external view returns (bytes32 configHash_) {
        return _configurationHash;
    }

    function protocolRootActivationV1()
        external
        view
        returns (bytes4 magic_, address factory_, bytes32 campaignKey_, uint8 state_)
    {
        return (_PRA1, _factory, _campaignKey, _activationState);
    }

    function activateProtocolRootV1(bytes32 _key) external returns (bytes4 magic_) {
        if (msg.sender != _factory || _key != _campaignKey || _activationState != 0) {
            revert InvalidActivation();
        }
        _activationState = 1;
        if (_failActivation) return bytes4(0);
        return _RAA1;
    }

    fallback() external {
        if (msg.sig != _rootViewSelector || msg.data.length != 4) revert InvalidRootView();
        bytes memory response = _rootView;
        assembly ("memory-safe") {
            return(add(response, 32), mload(response))
        }
    }

    error DeploymentClosed();
    error InvalidActivation();
    error InvalidRootView();
}

contract ProtocolRootFactoryV1Test is Test {
    address private constant _PROPOSER = address(0xA11CE);
    address private constant _DAO = _PROPOSER;
    bytes32 private constant _NAMESPACE = keccak256("root-manifest-namespace");
    bytes32 private constant _OPERATION_DOMAIN =
        keccak256("slot-chain-protocol-change-operation-v1");
    uint64 private constant _DELAY = 604_800;
    uint64 private constant _CAMPAIGN_LIFETIME = 2_592_000;
    uint64 private constant _GENESIS = 1_000_000;
    bytes4 private constant _BRC1_SELECTOR = 0x66f0bd82;
    bytes4 private constant _SOC1_SELECTOR = 0xe3d91a33;
    bytes4 private constant _PCT1_SELECTOR = 0xb80095ca;
    bytes4 private constant _PVM1_SELECTOR = 0x4deb7821;
    bytes4 private constant _EXECUTOR_CONFIRM_SELECTOR = 0xb1372f22;
    uint8 private constant _MUTATE_PCT_DAO = 1;
    uint8 private constant _MUTATE_PCT_DOMAIN = 2;
    uint8 private constant _MUTATE_PVM_TIMELOCK = 3;
    uint8 private constant _MUTATE_PVM_CLOCK = 4;
    uint8 private constant _MUTATE_PVM_ZERO_GAS = 5;
    uint8 private constant _MUTATE_BRC_WIDE_LEASE = 6;
    uint8 private constant _MUTATE_BRC_ECONOMICS = 7;
    uint8 private constant _MUTATE_BRC_RUNTIME = 8;
    uint8 private constant _MUTATE_SOC_LOOKAHEAD = 9;
    uint8 private constant _MUTATE_SOC_SUPPORT = 10;
    uint8 private constant _MUTATE_PVM_PAIR = 11;

    RootMigrationExecutorV1 private _executor;
    ProtocolRootFactoryV1 private _factory;
    RootDeployGate private _gate;
    bytes private _manifest;
    bytes[9] private _initCode;
    address[9] private _component;
    bytes32[9] private _configurationHash;
    bytes32 private _campaignKey;

    function setUp() public {
        vm.warp(_GENESIS);
        _executor = new RootMigrationExecutorV1(block.chainid, _PROPOSER);
        _factory = new ProtocolRootFactoryV1(
            block.chainid,
            _NAMESPACE,
            address(_executor),
            address(_executor).codehash,
            _executor.componentConfigHashV2()
        );
        _gate = new RootDeployGate();
        uint64 currentWindowAtStage = _DELAY / 384;
        _configureFixture(currentWindowAtStage + 18, 0, 0);
    }

    function test_stageProtocolRootV1_UsesExact1092ByteAbiAndCanonicalPrc() external {
        bytes memory canonical = abi.encodeCall(
            IProtocolRootFactoryV1.stageProtocolRootV1, (bytes32(uint256(1)), _manifest)
        );
        assertEq(canonical.length, 1092);

        bytes32 operationId = _stage();
        (bool success, bytes memory raw) = address(_factory).staticcall(
            abi.encodeCall(IProtocolRootFactoryV1.protocolRootCampaignV1, (_campaignKey))
        );
        assertTrue(success);
        assertEq(raw.length, 288);
        (
            bytes4 magic,
            bytes32 storedOperationId,
            bytes32 key,
            bytes32 manifestHash,
            uint8 state,
            uint64 generation,
            uint64 expiresAt,
            uint16 bitmap,
            bytes32 receipt
        ) = abi.decode(raw, (bytes4, bytes32, bytes32, bytes32, uint8, uint64, uint64, uint16, bytes32));
        assertEq(magic, bytes4(0x50524331));
        assertEq(storedOperationId, operationId);
        assertEq(key, _campaignKey);
        assertEq(manifestHash, _manifestHash());
        assertEq(state, 1);
        assertEq(generation, 0);
        assertEq(expiresAt, block.timestamp + _CAMPAIGN_LIFETIME);
        assertEq(bitmap, 0);
        assertEq(receipt, bytes32(0));
    }

    function test_protocolRootFactoryConfigV1_ReturnsExact544ByteStaticStruct() external view {
        (bool success, bytes memory raw) = address(_factory).staticcall(
            abi.encodeCall(IProtocolRootFactoryV1.protocolRootFactoryConfigV1, ())
        );
        assertTrue(success);
        assertEq(raw.length, 544);
        IProtocolRootFactoryV1.ProtocolRootFactoryConfigV1 memory config =
            abi.decode(raw, (IProtocolRootFactoryV1.ProtocolRootFactoryConfigV1));
        assertEq(config.magic, bytes4(0x50524631));
        assertEq(config.settlementChainId, block.chainid);
        assertEq(config.manifestNamespace, _NAMESPACE);
        assertEq(config.delayedExecutor, address(_executor));
        assertEq(config.executorRuntimeHash, address(_executor).codehash);
        assertEq(config.executorConfigurationHash, _executor.componentConfigHashV2());
        assertEq(
            config.proxyCreationCodeHash,
            keccak256(type(ProtocolRootCreate3ProxyV1).creationCode)
        );
        assertEq(config.proxyRuntimeHash, keccak256(type(ProtocolRootCreate3ProxyV1).runtimeCode));
        assertEq(config.campaignLifetime, _CAMPAIGN_LIFETIME);
        assertEq(config.deploymentPostcheckReserve, 500_000);
        assertEq(config.minimumFirstManagedRunwayWindows, 18);
        assertEq(config.executorConfigReadGas, 100_000);
        assertEq(config.componentConfigReadGas, 50_000);
        assertEq(config.activationCallGas, 50_000);
        assertEq(config.externalReadGas, 100_000);
        assertEq(config.executorConfirmCallGas, 500_000);
        assertEq(config.configurationHash, _factory.componentConfigHashV2());
    }

    function test_stageProtocolRootV1_RevertWhen_AbiHasGapSuffixOrDirtyPadding() external {
        bytes32 operationId = keccak256("operation");
        bytes memory canonical =
            abi.encodeCall(IProtocolRootFactoryV1.stageProtocolRootV1, (operationId, _manifest));

        _assertFactoryRawRevert(
            bytes.concat(canonical, bytes32(0)),
            ProtocolRootFactoryV1.NonCanonicalFactoryCalldata.selector,
            address(_executor)
        );

        bytes memory dirtyPadding = canonical;
        dirtyPadding[dirtyPadding.length - 1] = 0x01;
        _assertFactoryRawRevert(
            dirtyPadding,
            ProtocolRootFactoryV1.NonCanonicalFactoryCalldata.selector,
            address(_executor)
        );

        _assertFactoryRawRevert(
            _gappedStageCalldata(operationId, _manifest),
            ProtocolRootFactoryV1.NonCanonicalFactoryCalldata.selector,
            address(_executor)
        );
    }

    function test_stageProtocolRootV1_RevertWhen_GenerationUsesTerminalSentinel() external {
        _configureFixture(type(uint64).max, 0, type(uint64).max);
        vm.store(address(_factory), bytes32(0), bytes32(uint256(type(uint64).max)));
        vm.prank(address(_executor));
        vm.expectRevert(ProtocolRootFactoryV1.ProtocolRootGenerationExhausted.selector);
        _factory.stageProtocolRootV1(keccak256("operation"), _manifest);
    }

    function test_deployProtocolRootComponentV1_UsesCanonicalVariableAbiAndRetriesAfterRollback()
        external
    {
        _stage();
        bytes memory canonical = abi.encodeCall(
            IProtocolRootFactoryV1.deployProtocolRootComponentV1,
            (_campaignKey, uint8(1), _initCode[0])
        );
        uint256 padded = (_initCode[0].length + 31) & ~uint256(31);
        assertEq(canonical.length, 132 + padded);

        _assertFactoryRawRevert(
            bytes.concat(canonical, bytes32(0)),
            ProtocolRootFactoryV1.NonCanonicalFactoryCalldata.selector,
            address(this)
        );
        bytes memory dirtyPadding = canonical;
        dirtyPadding[dirtyPadding.length - 1] = 0x01;
        _assertFactoryRawRevert(
            dirtyPadding,
            ProtocolRootFactoryV1.NonCanonicalFactoryCalldata.selector,
            address(this)
        );

        _gate.setAllowed(false);
        address proxy = _proxyAddress(_campaignKey, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRootBootstrapV1.BootstrapExternalCallFailed.selector,
                proxy,
                ProtocolRootCreate3ProxyV1.deployV1.selector
            )
        );
        _factory.deployProtocolRootComponentV1(_campaignKey, 1, _initCode[0]);
        assertEq(proxy.code.length, 0);
        assertEq(_component[0].code.length, 0);

        _gate.setAllowed(true);
        assertEq(
            _factory.deployProtocolRootComponentV1(_campaignKey, 1, _initCode[0]),
            _component[0]
        );
        assertGt(proxy.code.length, 0);
        assertGt(_component[0].code.length, 0);
    }

    function test_campaignDeadline_IsInclusiveForDeployAndStrictForAbort() external {
        bytes32 operationId = _stage();
        (,,,,,, uint64 expiresAt,,) = _factory.protocolRootCampaignV1(_campaignKey);

        vm.warp(expiresAt);
        _factory.deployProtocolRootComponentV1(_campaignKey, 1, _initCode[0]);
        vm.expectRevert(ProtocolRootFactoryV1.ProtocolRootCampaignNotAbortable.selector);
        _factory.abortProtocolRootCampaignV1(_campaignKey);

        vm.warp(expiresAt + 1);
        vm.expectRevert(ProtocolRootFactoryV1.ProtocolRootComponentNotDeployable.selector);
        _factory.deployProtocolRootComponentV1(_campaignKey, 2, _initCode[1]);
        _factory.abortProtocolRootCampaignV1(_campaignKey);

        (,,,, uint8 state,,, uint16 bitmap,) = _factory.protocolRootCampaignV1(_campaignKey);
        assertEq(state, 3);
        assertEq(bitmap, 1);
        _executor.clearAbortedRootMigrationV1(operationId, _campaignKey);
        (, uint8 authorityState,,,,,,,) = _executor.rootMigrationAuthorityV1();
        assertEq(authorityState, 0);
    }

    function test_finalizeProtocolRootV1_AcceptsExactRunwayAndAtomicallyConfirmsExecutor() external {
        bytes32 operationId = _stage();
        _deployAll();
        bytes32 receipt = _factory.finalizeProtocolRootV1(_campaignKey);
        assertTrue(receipt != bytes32(0));

        (,,,, uint8 campaignState,,, uint16 bitmap, bytes32 storedReceipt) =
            _factory.protocolRootCampaignV1(_campaignKey);
        assertEq(campaignState, 2);
        assertEq(bitmap, 0x01ff);
        assertEq(storedReceipt, receipt);
        (, uint8 operationState,,,,,,,,) = _executor.rootMigrationOperationV1(operationId);
        assertEq(operationState, 4);
        (, uint8 authorityState,,,, address activeFactory, bytes32 activeOperationId,, bytes32 activeReceipt) =
            _executor.rootMigrationAuthorityV1();
        assertEq(authorityState, 2);
        assertEq(activeFactory, address(_factory));
        assertEq(activeOperationId, operationId);
        assertEq(activeReceipt, receipt);
        _assertAllActivationStates(1);
    }

    function test_finalizeProtocolRootV1_RevertWhen_FirstManagedIsMaxOrBelowRunway() external {
        _configureFixture(type(uint64).max, 0, 0);
        _stage();
        _deployAll();
        vm.expectRevert(ProtocolRootFactoryV1.InsufficientFirstManagedWindowRunway.selector);
        _factory.finalizeProtocolRootV1(_campaignKey);
        _assertAllActivationStates(0);

        setUp();
        uint64 currentWindowAtStage = _DELAY / 384;
        _configureFixture(currentWindowAtStage + 17, 0, 0);
        _stage();
        _deployAll();
        vm.expectRevert(ProtocolRootFactoryV1.InsufficientFirstManagedWindowRunway.selector);
        _factory.finalizeProtocolRootV1(_campaignKey);
        _assertAllActivationStates(0);
    }

    function test_finalizeProtocolRootV1_RollsBackEveryActivationOnComponentOrExecutorFailure()
        external
    {
        _configureFixture(_DELAY / 384 + 18, 9, 0);
        _stage();
        _deployAll();
        vm.expectRevert(
            abi.encodeWithSelector(ProtocolRootFactoryV1.ProtocolRootActivationFailed.selector, 9)
        );
        _factory.finalizeProtocolRootV1(_campaignKey);
        _assertAllActivationStates(0);

        setUp();
        _stage();
        _deployAll();
        vm.store(address(_executor), bytes32(uint256(1)), bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibRootBootstrapV1.BootstrapExternalCallFailed.selector,
                address(_executor),
                _EXECUTOR_CONFIRM_SELECTOR
            )
        );
        _factory.finalizeProtocolRootV1(_campaignKey);
        _assertAllActivationStates(0);
        (,,,, uint8 campaignState,,,,) = _factory.protocolRootCampaignV1(_campaignKey);
        assertEq(campaignState, 1);
    }

    function test_finalizeProtocolRootV1_RevertWhen_PctDaoDomainOrPvmTimelockJoinMutates()
        external
    {
        _assertGraphMutation(
            _MUTATE_PCT_DAO,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidProtocolChangeTimelockRootJoin.selector)
        );
        setUp();
        _assertGraphMutation(
            _MUTATE_PCT_DOMAIN,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidProtocolChangeTimelockRootJoin.selector)
        );
        setUp();
        _assertGraphMutation(
            _MUTATE_PVM_TIMELOCK,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidProtocolChangeTimelockRootJoin.selector)
        );
    }

    function test_finalizeProtocolRootV1_RevertWhen_PvmClockGasOrRuntimeConfigPairMutates()
        external
    {
        _assertGraphMutation(
            _MUTATE_PVM_CLOCK,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidProtocolVersionManagerRootJoin.selector)
        );
        setUp();
        _assertGraphMutation(
            _MUTATE_PVM_ZERO_GAS,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidProtocolVersionManagerRootJoin.selector)
        );
        setUp();
        _assertGraphMutation(
            _MUTATE_PVM_PAIR,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidProtocolVersionManagerRootJoin.selector)
        );
    }

    function test_finalizeProtocolRootV1_RevertWhen_BrcWidthEconomicsOrRuntimeMutates()
        external
    {
        _assertGraphMutation(
            _MUTATE_BRC_WIDE_LEASE,
            abi.encodeWithSelector(LibRootBootstrapV1.BootstrapMalformedWord.selector, 5)
        );
        setUp();
        _assertGraphMutation(
            _MUTATE_BRC_ECONOMICS,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidBuilderRegistryRootJoin.selector)
        );
        setUp();
        _assertGraphMutation(
            _MUTATE_BRC_RUNTIME,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidBuilderRegistryRootJoin.selector)
        );
    }

    function test_finalizeProtocolRootV1_RevertWhen_SocLookaheadOrSupportBoundaryMutates()
        external
    {
        _assertGraphMutation(
            _MUTATE_SOC_LOOKAHEAD,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidScheduleOracleRootJoin.selector)
        );
        setUp();
        _assertGraphMutation(
            _MUTATE_SOC_SUPPORT,
            abi.encodeWithSelector(ProtocolRootFactoryV1.InvalidScheduleOracleRootJoin.selector)
        );
    }

    function _stage() private returns (bytes32 operationId_) {
        bytes32 manifestHash = _manifestHash();
        bytes32 factoryConfigurationHash = _factory.componentConfigHashV2();
        vm.prank(_PROPOSER);
        operationId_ = _executor.queueRootMigrationV1(
            address(_factory), manifestHash, address(_factory).codehash, factoryConfigurationHash
        );
        vm.warp(block.timestamp + _DELAY);
        _executor.executeRootMigrationV1(operationId_, address(_factory), _manifest);
    }

    function _deployAll() private {
        for (uint8 role = 1; role <= 9; ++role) {
            assertEq(
                _factory.deployProtocolRootComponentV1(_campaignKey, role, _initCode[role - 1]),
                _component[role - 1]
            );
        }
    }

    function _assertGraphMutation(uint8 _mutation, bytes memory _expectedError) private {
        _configureFixtureWithMutation(_DELAY / 384 + 18, 0, 0, _mutation);
        _stage();
        _deployAll();
        vm.expectRevert(_expectedError);
        _factory.finalizeProtocolRootV1(_campaignKey);
        _assertAllActivationStates(0);
    }

    function _assertAllActivationStates(uint8 _expected) private view {
        for (uint256 i; i < 9; ++i) {
            (,,, uint8 state) = FactoryRoleMock(_component[i]).protocolRootActivationV1();
            assertEq(state, _expected);
        }
    }

    function _configureFixture(
        uint64 _firstManagedWindow,
        uint8 _failingActivationRole,
        uint64 _manifestGeneration
    )
        private
    {
        _configureFixtureWithMutation(
            _firstManagedWindow, _failingActivationRole, _manifestGeneration, 0
        );
    }

    function _configureFixtureWithMutation(
        uint64 _firstManagedWindow,
        uint8 _failingActivationRole,
        uint64 _manifestGeneration,
        uint8 _mutation
    )
        private
    {
        _campaignKey = _deriveCampaignKey(_manifestGeneration);
        bytes32 runtimeHash = keccak256(type(FactoryRoleMock).runtimeCode);
        for (uint8 role = 1; role <= 9; ++role) {
            _component[role - 1] = _componentAddress(_campaignKey, role);
            _configurationHash[role - 1] = keccak256(abi.encodePacked("role-config", role));
        }

        bytes memory pct = _buildPctRow(runtimeHash);
        _configurationHash[2] = _timelockConfigurationHash(runtimeHash);
        bytes memory pvm = _buildPvmRow(runtimeHash);
        if (_mutation == _MUTATE_PCT_DAO) {
            _setRowWord(pct, 1, bytes32(uint256(uint160(address(0xBAD)))));
        } else if (_mutation == _MUTATE_PCT_DOMAIN) {
            _setRowWord(pct, 4, keccak256("wrong-operation-domain"));
        } else if (_mutation == _MUTATE_PVM_TIMELOCK) {
            _setRowWord(pvm, 12, keccak256("wrong-timelock-descriptor"));
        } else if (_mutation == _MUTATE_PVM_CLOCK) {
            _setRowWord(pvm, 14, bytes32(uint256(604_799)));
        } else if (_mutation == _MUTATE_PVM_ZERO_GAS) {
            _setRowWord(pvm, 18, bytes32(0));
        } else if (_mutation == _MUTATE_PVM_PAIR) {
            _setRowWord(pvm, 23, keccak256("wrong-role-five-config"));
        }
        _configurationHash[3] = _pvmConfigurationHash(pvm);
        bytes memory brc = _buildBrcRow(runtimeHash, _firstManagedWindow);
        if (_mutation == _MUTATE_BRC_WIDE_LEASE) {
            _setRowWord(brc, 5, bytes32(uint256(1) << 192));
        } else if (_mutation == _MUTATE_BRC_ECONOMICS) {
            _setRowWord(brc, 5, bytes32(uint256(2_001)));
        } else if (_mutation == _MUTATE_BRC_RUNTIME) {
            _setRowWord(brc, 15, keccak256("wrong-router-runtime"));
            _setRowWord(brc, 20, _builderTopologyHash(brc));
        }
        bytes memory soc = _buildSocRow(runtimeHash, _firstManagedWindow, brc);
        if (_mutation == _MUTATE_SOC_LOOKAHEAD) {
            _setRowWord(soc, 8, bytes32(uint256(767)));
        } else if (_mutation == _MUTATE_SOC_SUPPORT) {
            uint256 firstManagedStart =
                uint256(_GENESIS) + uint256(_firstManagedWindow) * 384;
            _setRowWord(soc, 7, bytes32(firstManagedStart - 3_071));
        }

        for (uint8 role = 1; role <= 9; ++role) {
            bytes4 selector;
            bytes memory response;
            if (role == 1) {
                selector = _BRC1_SELECTOR;
                response = brc;
            } else if (role == 2) {
                selector = _SOC1_SELECTOR;
                response = soc;
            } else if (role == 3) {
                selector = _PCT1_SELECTOR;
                response = pct;
            } else if (role == 4) {
                selector = _PVM1_SELECTOR;
                response = pvm;
            }
            _initCode[role - 1] =
                _roleInitCode(role, selector, response, role == _failingActivationRole);
        }

        bytes memory manifest = new bytes(969);
        manifest[0] = 0x01;
        _writeWord(manifest, 1, bytes32(block.chainid));
        _writeWord(manifest, 33, bytes32(uint256(_manifestGeneration) << 192));
        _writeWord(manifest, 41, _NAMESPACE);
        for (uint8 role = 1; role <= 9; ++role) {
            uint256 offset = 105 + uint256(role - 1) * 96;
            _writeWord(manifest, offset, keccak256(_initCode[role - 1]));
            _writeWord(manifest, offset + 32, runtimeHash);
            _writeWord(manifest, offset + 64, _configurationHash[role - 1]);
        }
        _manifest = manifest;
    }

    function _roleInitCode(
        uint8 _role,
        bytes4 _selector,
        bytes memory _response,
        bool _failActivation
    )
        private
        view
        returns (bytes memory initCode_)
    {
        return abi.encodePacked(
            type(FactoryRoleMock).creationCode,
            abi.encode(
                address(_factory),
                _campaignKey,
                _configurationHash[_role - 1],
                _selector,
                _response,
                _gate,
                _failActivation
            )
        );
    }

    function _buildBrcRow(bytes32 _runtimeHash, uint64 _firstManagedWindow)
        private
        view
        returns (bytes memory row_)
    {
        row_ = new bytes(672);
        _setRowWord(row_, 0, bytes32(bytes4(0x42524331)));
        _setRowWord(row_, 1, bytes32(block.chainid));
        _setRowWord(row_, 2, bytes32(uint256(uint160(address(0x1111)))));
        _setRowWord(row_, 3, keccak256("token-runtime"));
        _setRowWord(row_, 4, bytes32(uint256(18)));
        _setRowWord(row_, 5, bytes32(uint256(1_000)));
        _setRowWord(row_, 6, bytes32(uint256(2_000)));
        _setRowWord(row_, 7, bytes32(uint256(200)));
        _setRowWord(row_, 8, bytes32(uint256(_GENESIS)));
        _setRowWord(row_, 9, bytes32(uint256(64)));
        _setRowWord(row_, 10, bytes32(uint256(64)));
        _setRowWord(row_, 11, bytes32(uint256(_firstManagedWindow)));
        _setRowWord(row_, 12, bytes32(uint256(uint160(address(0x2222)))));
        _setRowWord(row_, 13, bytes32(uint256(64)));
        _setRowWord(row_, 14, bytes32(uint256(uint160(_component[4]))));
        _setRowWord(row_, 15, _runtimeHash);
        _setRowWord(row_, 16, _configurationHash[4]);
        _setRowWord(row_, 17, bytes32(uint256(uint160(_component[1]))));
        _setRowWord(row_, 18, _runtimeHash);
        _setRowWord(row_, 19, _configurationHash[0]);
        _setRowWord(row_, 20, _builderTopologyHash(row_));
    }

    function _buildSocRow(
        bytes32,
        uint64 _firstManagedWindow,
        bytes memory _brc
    )
        private
        view
        returns (bytes memory row_)
    {
        row_ = new bytes(416);
        _setRowWord(row_, 0, bytes32(bytes4(0x534f4331)));
        _setRowWord(row_, 1, bytes32(block.chainid));
        _setRowWord(row_, 2, bytes32(uint256(uint160(_component[3]))));
        _setRowWord(row_, 3, bytes32(uint256(uint160(_component[4]))));
        _setRowWord(row_, 4, bytes32(uint256(uint160(_component[0]))));
        _setRowWord(row_, 5, bytes32(uint256(_firstManagedWindow)));
        _setRowWord(row_, 6, bytes32(uint256(_GENESIS)));
        _setRowWord(row_, 7, bytes32(uint256(_GENESIS - 10_000)));
        _setRowWord(row_, 8, bytes32(uint256(768)));
        _setRowWord(row_, 9, bytes32(uint256(1_000)));
        _setRowWord(row_, 10, bytes32(bytes4(0x01020304)));
        _setRowWord(row_, 11, _rowWord(_brc, 20));
        _setRowWord(row_, 12, _configurationHash[1]);
    }

    function _buildPctRow(bytes32 _runtimeHash) private view returns (bytes memory row_) {
        row_ = new bytes(160);
        _setRowWord(row_, 0, bytes32(bytes4(0x50435431)));
        _setRowWord(row_, 1, bytes32(uint256(uint160(_DAO))));
        _setRowWord(row_, 2, bytes32(uint256(uint160(_component[3]))));
        _setRowWord(row_, 3, bytes32(uint256(604_800)));
        _setRowWord(row_, 4, _OPERATION_DOMAIN);
        _runtimeHash;
    }

    function _buildPvmRow(bytes32 _runtimeHash) private view returns (bytes memory row_) {
        row_ = new bytes(1088);
        _setRowWord(row_, 0, bytes32(bytes4(0x50564d31)));
        _setRowWord(row_, 1, bytes32(block.chainid));
        uint8[8] memory words = [uint8(2), 3, 4, 5, 6, 7, 10, 11];
        uint8[8] memory roles = [uint8(3), 5, 6, 1, 2, 7, 8, 9];
        for (uint256 i; i < 8; ++i) {
            _setRowWord(row_, words[i], bytes32(uint256(uint160(_component[roles[i] - 1]))));
        }
        _setRowWord(row_, 8, _runtimeHash);
        _setRowWord(row_, 9, _configurationHash[6]);
        _setRowWord(row_, 12, _configurationHash[2]);
        _setRowWord(row_, 13, _NAMESPACE);
        _setRowWord(row_, 14, bytes32(uint256(604_800)));
        _setRowWord(row_, 15, bytes32(uint256(604_800)));
        _setRowWord(row_, 16, bytes32(uint256(604_800)));
        _setRowWord(row_, 17, bytes32(uint256(64)));
        for (uint256 i = 18; i <= 21; ++i) {
            _setRowWord(row_, i, bytes32(uint256(100_000 + i)));
        }
        uint8[6] memory pairWords = [uint8(22), 24, 26, 28, 30, 32];
        uint8[6] memory pairRoles = [uint8(5), 6, 1, 2, 8, 9];
        for (uint256 i; i < 6; ++i) {
            uint8 role = pairRoles[i];
            _setRowWord(row_, pairWords[i], _runtimeHash);
            _setRowWord(row_, pairWords[i] + 1, _configurationHash[role - 1]);
        }
    }

    function _builderTopologyHash(bytes memory _brc) private pure returns (bytes32 hash_) {
        bytes memory head = abi.encodePacked(
            uint256(_rowWord(_brc, 1)),
            address(uint160(uint256(_rowWord(_brc, 2)))),
            _rowWord(_brc, 3),
            uint8(uint256(_rowWord(_brc, 4))),
            uint64(uint256(_rowWord(_brc, 8))),
            uint64(uint256(_rowWord(_brc, 9))),
            uint64(uint256(_rowWord(_brc, 10))),
            uint64(uint256(_rowWord(_brc, 11)))
        );
        bytes memory tail = abi.encodePacked(
            address(uint160(uint256(_rowWord(_brc, 12)))),
            uint64(uint256(_rowWord(_brc, 13))),
            address(uint160(uint256(_rowWord(_brc, 14)))),
            _rowWord(_brc, 15),
            _rowWord(_brc, 16),
            address(uint160(uint256(_rowWord(_brc, 17)))),
            _rowWord(_brc, 18),
            _rowWord(_brc, 19)
        );
        return keccak256(
            bytes.concat("slot-chain-builder-registry-topology-v1", bytes2(uint16(313)), head, tail)
        );
    }

    function _pvmConfigurationHash(bytes memory _pvm) private pure returns (bytes32 hash_) {
        bytes memory identities = abi.encodePacked(
            "slot-chain-protocol-version-manager-config-v1",
            uint256(_rowWord(_pvm, 1)),
            address(uint160(uint256(_rowWord(_pvm, 2)))),
            _rowWord(_pvm, 12),
            address(uint160(uint256(_rowWord(_pvm, 3)))),
            _rowWord(_pvm, 22),
            _rowWord(_pvm, 23),
            address(uint160(uint256(_rowWord(_pvm, 4)))),
            _rowWord(_pvm, 24),
            _rowWord(_pvm, 25)
        );
        bytes memory controlsA = abi.encodePacked(
            address(uint160(uint256(_rowWord(_pvm, 5)))),
            _rowWord(_pvm, 26),
            _rowWord(_pvm, 27),
            address(uint160(uint256(_rowWord(_pvm, 6)))),
            _rowWord(_pvm, 28),
            _rowWord(_pvm, 29)
        );
        bytes memory controlsB = abi.encodePacked(
            address(uint160(uint256(_rowWord(_pvm, 7)))),
            _rowWord(_pvm, 8),
            _rowWord(_pvm, 9),
            address(uint160(uint256(_rowWord(_pvm, 10)))),
            _rowWord(_pvm, 30),
            _rowWord(_pvm, 31)
        );
        bytes memory controlsC = abi.encodePacked(
            address(uint160(uint256(_rowWord(_pvm, 11)))),
            _rowWord(_pvm, 32),
            _rowWord(_pvm, 33)
        );
        bytes memory policy = abi.encodePacked(
            _rowWord(_pvm, 13),
            uint64(uint256(_rowWord(_pvm, 14))),
            uint64(uint256(_rowWord(_pvm, 15))),
            uint64(uint256(_rowWord(_pvm, 16))),
            uint16(uint256(_rowWord(_pvm, 17))),
            uint64(uint256(_rowWord(_pvm, 18))),
            uint64(uint256(_rowWord(_pvm, 19))),
            uint64(uint256(_rowWord(_pvm, 20))),
            uint64(uint256(_rowWord(_pvm, 21)))
        );
        return keccak256(bytes.concat(identities, controlsA, controlsB, controlsC, policy));
    }

    function _timelockConfigurationHash(bytes32 _runtimeHash) private view returns (bytes32 hash_) {
        return keccak256(
            abi.encodePacked(
                "slot-chain-protocol-change-timelock-v1",
                block.chainid,
                _component[2],
                _runtimeHash,
                _DAO,
                _component[3],
                uint64(604_800),
                _OPERATION_DOMAIN
            )
        );
    }

    function _deriveCampaignKey(uint64 _generation) private view returns (bytes32 key_) {
        return keccak256(
            abi.encodePacked(
                "slot-chain-protocol-root-campaign-v1",
                block.chainid,
                address(_factory),
                _generation,
                _NAMESPACE,
                bytes32(0)
            )
        );
    }

    function _manifestHash() private view returns (bytes32 hash_) {
        return keccak256(
            abi.encodePacked("slot-chain-protocol-root-manifest-v1", uint16(969), _manifest)
        );
    }

    function _proxyAddress(bytes32 _key, uint8 _role) private view returns (address proxy_) {
        bytes32 salt =
            keccak256(abi.encodePacked("slot-chain-protocol-root-component-v1", _key, _role));
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(_factory),
                            salt,
                            keccak256(type(ProtocolRootCreate3ProxyV1).creationCode)
                        )
                    )
                )
            )
        );
    }

    function _componentAddress(bytes32 _key, uint8 _role) private view returns (address component_) {
        address proxy = _proxyAddress(_key, _role);
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", proxy, hex"01")))));
    }

    function _gappedStageCalldata(bytes32 _operationId, bytes memory _value)
        private
        pure
        returns (bytes memory calldata_)
    {
        bytes memory padded = new bytes(992);
        for (uint256 i; i < _value.length; ++i) padded[i] = _value[i];
        return bytes.concat(
            IProtocolRootFactoryV1.stageProtocolRootV1.selector,
            _operationId,
            bytes32(uint256(96)),
            bytes32(0),
            bytes32(uint256(_value.length)),
            padded
        );
    }

    function _assertFactoryRawRevert(bytes memory _calldata, bytes4 _selector, address _caller)
        private
    {
        vm.prank(_caller);
        (bool success, bytes memory returndata) = address(_factory).call(_calldata);
        assertFalse(success);
        assertGe(returndata.length, 4);
        assertEq(bytes4(returndata), _selector);
    }

    function _setRowWord(bytes memory _row, uint256 _index, bytes32 _word) private pure {
        assembly ("memory-safe") {
            mstore(add(add(_row, 32), mul(_index, 32)), _word)
        }
    }

    function _rowWord(bytes memory _row, uint256 _index) private pure returns (bytes32 word_) {
        assembly ("memory-safe") {
            word_ := mload(add(add(_row, 32), mul(_index, 32)))
        }
    }

    function _writeWord(bytes memory _value, uint256 _offset, bytes32 _word) private pure {
        assembly ("memory-safe") {
            mstore(add(add(_value, 32), _offset), _word)
        }
    }
}
