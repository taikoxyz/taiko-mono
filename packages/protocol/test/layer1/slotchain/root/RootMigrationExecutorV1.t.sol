// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    RootMigrationExecutorV1
} from "../../../../contracts/layer1/slotchain/root/RootMigrationExecutorV1.sol";
import {
    IRootMigrationExecutorV1
} from "../../../../contracts/layer1/slotchain/root/iface/IRootMigrationExecutorV1.sol";
import {
    LibRootBootstrapV1
} from "../../../../contracts/layer1/slotchain/root/libs/LibRootBootstrapV1.sol";
import { Test } from "forge-std/src/Test.sol";

contract RootFactoryMock {
    bytes4 private constant _STG1 = 0x53544731;
    bytes4 private constant _PRC1 = 0x50524331;
    bytes4 private constant _FACTORY_CONFIG_SELECTOR = 0xd7b40838;
    bytes32 private constant _PROXY_CREATION_HASH = keccak256("proxy-creation");
    bytes32 private constant _PROXY_RUNTIME_HASH = keccak256("proxy-runtime");

    RootMigrationExecutorV1 private immutable _executor;
    bytes32 private immutable _configurationHash;
    bytes32 private immutable _namespace = keccak256("factory-namespace");

    uint8 private _mode;
    bytes32 private _operationId;
    bytes32 private _campaignKey;
    bytes32 private _manifestHash;
    uint8 private _campaignState;
    uint64 private _generation;
    uint64 private _expiresAt;
    uint16 private _deployedBitmap;
    bytes32 private _rootReceipt;
    bool private _requireCandidateDuringReads;

    error CandidateAuthorityMissing();

    constructor(RootMigrationExecutorV1 _executorAddress, bytes32 _configHash) {
        _executor = _executorAddress;
        _configurationHash = _configHash;
    }

    function componentConfigHashV2() external view returns (bytes32 configHash_) {
        if (_requireCandidateDuringReads) _assertCandidateAuthority();
        return _configurationHash;
    }

    fallback() external {
        if (msg.sig != _FACTORY_CONFIG_SELECTOR || msg.data.length != 4) revert();
        if (_requireCandidateDuringReads) _assertCandidateAuthority();

        bytes memory response = new bytes(544);
        address executorAddress = address(_executor);
        bytes32 executorRuntimeHash = executorAddress.codehash;
        bytes32 executorConfigurationHash = _executor.componentConfigHashV2();
        bytes32 namespace = _namespace;
        bytes32 configurationHash = _configurationHash;
        bytes32 proxyCreationHash = _PROXY_CREATION_HASH;
        bytes32 proxyRuntimeHash = _PROXY_RUNTIME_HASH;
        assembly ("memory-safe") {
            let start := add(response, 32)
            mstore(start, shl(224, 0x50524631))
            mstore(add(start, 32), chainid())
            mstore(add(start, 64), namespace)
            mstore(add(start, 96), executorAddress)
            mstore(add(start, 128), executorRuntimeHash)
            mstore(add(start, 160), executorConfigurationHash)
            mstore(add(start, 192), proxyCreationHash)
            mstore(add(start, 224), proxyRuntimeHash)
            mstore(add(start, 256), 2592000)
            mstore(add(start, 288), 500000)
            mstore(add(start, 320), 18)
            mstore(add(start, 352), 100000)
            mstore(add(start, 384), 50000)
            mstore(add(start, 416), 50000)
            mstore(add(start, 448), 100000)
            mstore(add(start, 480), 500000)
            mstore(add(start, 512), configurationHash)
            return(start, 544)
        }
    }

    function stageProtocolRootV1(
        bytes32 _expectedOperationId,
        bytes calldata _manifest
    )
        external
        returns (bytes4, bytes32, bytes32, bytes32, uint64, uint64)
    {
        bytes32 derivedCampaignKey = _deriveCampaignKey(_manifest);
        bytes32 manifestHash = _deriveManifestHash(_manifest);
        _operationId = _expectedOperationId;
        _campaignKey = derivedCampaignKey;
        _manifestHash = manifestHash;
        _campaignState = _mode == 2 ? 0 : 1;
        _generation = 1;
        _expiresAt = uint64(block.timestamp + 2_592_000);
        _deployedBitmap = 0;
        _rootReceipt = bytes32(0);

        if (_mode == 3) {
            bytes memory shortReturn = abi.encode(
                _STG1, _expectedOperationId, derivedCampaignKey, manifestHash, _generation
            );
            assembly ("memory-safe") {
                return(add(shortReturn, 32), mload(shortReturn))
            }
        }
        if (_mode == 1) _expectedOperationId = keccak256("wrong-operation");
        return
            (_STG1, _expectedOperationId, derivedCampaignKey, manifestHash, _generation, _expiresAt);
    }

    function protocolRootCampaignV1(bytes32)
        external
        view
        returns (bytes4, bytes32, bytes32, bytes32, uint8, uint64, uint64, uint16, bytes32)
    {
        return (
            _PRC1,
            _operationId,
            _campaignKey,
            _manifestHash,
            _campaignState,
            _generation,
            _expiresAt,
            _deployedBitmap,
            _rootReceipt
        );
    }

    function setMode(uint8 _newMode) external {
        _mode = _newMode;
    }

    function requireCandidateDuringReads() external {
        _requireCandidateDuringReads = true;
    }

    function setCampaignState(
        uint8 _state,
        uint64 _newGeneration,
        uint64 _newExpiresAt,
        uint16 _bitmap,
        bytes32 _receipt
    )
        external
    {
        _campaignState = _state;
        _generation = _newGeneration;
        _expiresAt = _newExpiresAt;
        _deployedBitmap = _bitmap;
        _rootReceipt = _receipt;
    }

    function confirmCurrent(bytes32 _receipt) external returns (bytes4 magic_) {
        return _executor.confirmRootMigrationV1(_operationId, _campaignKey, _receipt);
    }

    function clearCurrent() external {
        _executor.clearAbortedRootMigrationV1(_operationId, _campaignKey);
    }

    function activateAndConfirm(bytes32 _receipt) external returns (bytes4 magic_) {
        _campaignState = 2;
        _deployedBitmap = 0x01ff;
        _rootReceipt = _receipt;
        return _executor.confirmRootMigrationV1(_operationId, _campaignKey, _receipt);
    }

    function abortAndClear() external {
        _campaignState = 3;
        _rootReceipt = bytes32(0);
        _executor.clearAbortedRootMigrationV1(_operationId, _campaignKey);
    }

    function campaignKey() external view returns (bytes32 key_) {
        return _campaignKey;
    }

    function campaignTiming() external view returns (uint64 generation_, uint64 expiresAt_) {
        return (_generation, _expiresAt);
    }

    function _assertCandidateAuthority() private view {
        (, uint8 state, address candidateFactory,,,,,,) = _executor.rootMigrationAuthorityV1();
        if (state != 1 || candidateFactory != address(this)) revert CandidateAuthorityMissing();
    }

    function _deriveManifestHash(bytes calldata _manifest) private pure returns (bytes32 hash_) {
        return keccak256(
            abi.encodePacked("slot-chain-protocol-root-manifest-v1", uint16(969), _manifest)
        );
    }

    function _deriveCampaignKey(bytes calldata _manifest) private view returns (bytes32 key_) {
        uint256 chainId;
        uint64 generation;
        bytes32 namespace;
        bytes32 predecessor;
        assembly ("memory-safe") {
            chainId := calldataload(add(_manifest.offset, 1))
            generation := shr(192, calldataload(add(_manifest.offset, 33)))
            namespace := calldataload(add(_manifest.offset, 41))
            predecessor := calldataload(add(_manifest.offset, 73))
        }
        return keccak256(
            abi.encodePacked(
                "slot-chain-protocol-root-campaign-v1",
                chainId,
                address(this),
                generation,
                namespace,
                predecessor
            )
        );
    }
}

contract RootMigrationExecutorV1Test is Test {
    address private constant _PROPOSER = address(0xA11CE);
    uint64 private constant _DELAY = 604_800;
    uint64 private constant _WINDOW = 604_800;
    bytes4 private constant _RAC1 = 0x52414331;

    RootMigrationExecutorV1 private _executor;
    RootFactoryMock private _factory;
    bytes private _manifest;
    bytes32 private _manifestHash;
    bytes32 private _factoryConfig;

    function setUp() public {
        vm.warp(1_000_000);
        _executor = new RootMigrationExecutorV1(block.chainid, _PROPOSER);
        _factoryConfig = keccak256("factory-config");
        _factory = new RootFactoryMock(_executor, _factoryConfig);
        _manifest = _buildManifest(0, keccak256("manifest-namespace"));
        _manifestHash = _deriveManifestHash(_manifest);
    }

    function test_views_ReturnExact320And288ByteCanonicalRows() external view {
        (bool success, bytes memory config) = address(_executor)
            .staticcall(abi.encodeCall(IRootMigrationExecutorV1.rootMigrationExecutorConfigV1, ()));
        assertTrue(success);
        assertEq(config.length, 320);

        bytes memory authority;
        (success, authority) = address(_executor)
            .staticcall(abi.encodeCall(IRootMigrationExecutorV1.rootMigrationAuthorityV1, ()));
        assertTrue(success);
        assertEq(authority.length, 288);

        bytes memory operation;
        (success, operation) = address(_executor)
            .staticcall(
                abi.encodeCall(
                    IRootMigrationExecutorV1.rootMigrationOperationV1, (keccak256("unknown"))
                )
            );
        assertTrue(success);
        assertEq(operation.length, 320);
        (, uint8 state, uint64 nonce, address factory,,,,,,) = abi.decode(
            operation,
            (bytes4, uint8, uint64, address, bytes32, bytes32, bytes32, uint64, uint64, uint64)
        );
        assertEq(state, 0);
        assertEq(nonce, 0);
        assertEq(factory, address(0));
    }

    function test_queueRootMigrationV1_PinsDelayWindowNonceAndOperationIdentity() external {
        bytes32 expectedId = _deriveOperationId(1);
        vm.expectEmit();
        emit IRootMigrationExecutorV1.RootMigrationQueued(
            expectedId,
            address(_factory),
            _manifestHash,
            address(_factory).codehash,
            _factoryConfig,
            1,
            uint64(block.timestamp) + _DELAY,
            uint64(block.timestamp) + _DELAY + _WINDOW
        );
        bytes32 operationId = _queue();
        assertEq(operationId, expectedId);

        (
            ,
            uint8 state,
            uint64 nonce,
            address factory,
            bytes32 manifestHash,,,
            uint64 queuedAt,
            uint64 executeAfter,
            uint64 executeBefore
        ) = _executor.rootMigrationOperationV1(operationId);
        assertEq(state, 1);
        assertEq(nonce, 1);
        assertEq(factory, address(_factory));
        assertEq(manifestHash, _manifestHash);
        assertEq(queuedAt, block.timestamp);
        assertEq(executeAfter, block.timestamp + _DELAY);
        assertEq(executeBefore, block.timestamp + _DELAY + _WINDOW);
    }

    function test_queueRootMigrationV1_RevertWhen_NonceUsesTerminalSentinel() external {
        vm.store(address(_executor), bytes32(0), bytes32(uint256(type(uint64).max)));
        vm.prank(_PROPOSER);
        vm.expectRevert(RootMigrationExecutorV1.RootMigrationNonceExhausted.selector);
        _executor.queueRootMigrationV1(
            address(_factory), _manifestHash, address(_factory).codehash, _factoryConfig
        );
    }

    function test_executeRootMigrationV1_DelayEndpointsAreInclusive() external {
        bytes32 operationId = _queue();
        vm.warp(block.timestamp + _DELAY - 1);
        vm.expectRevert(RootMigrationExecutorV1.RootMigrationNotExecutable.selector);
        _executor.executeRootMigrationV1(operationId, address(_factory), _manifest);

        vm.warp(block.timestamp + 1);
        _executor.executeRootMigrationV1(operationId, address(_factory), _manifest);
        (, uint8 state,,,,,,,,) = _executor.rootMigrationOperationV1(operationId);
        assertEq(state, 3);
    }

    function test_executeRootMigrationV1_ExecuteBeforeEndpointIsInclusive() external {
        bytes32 operationId = _queue();
        (,,,,,,,,, uint64 executeBefore) = _executor.rootMigrationOperationV1(operationId);
        vm.warp(executeBefore);
        _executor.executeRootMigrationV1(operationId, address(_factory), _manifest);

        (, uint8 state,,,,,,,,) = _executor.rootMigrationOperationV1(operationId);
        assertEq(state, 3);
    }

    function test_executeRootMigrationV1_RevertOneSecondAfterExecuteBefore() external {
        bytes32 operationId = _queue();
        (,,,,,,,,, uint64 executeBefore) = _executor.rootMigrationOperationV1(operationId);
        vm.warp(executeBefore + 1);
        vm.expectRevert(RootMigrationExecutorV1.RootMigrationNotExecutable.selector);
        _executor.executeRootMigrationV1(operationId, address(_factory), _manifest);
    }

    function test_executeRootMigrationV1_PublishesCandidateBeforeFactoryReads() external {
        bytes32 operationId = _queue();
        _factory.requireCandidateDuringReads();
        vm.warp(block.timestamp + _DELAY);
        _executor.executeRootMigrationV1(operationId, address(_factory), _manifest);

        (, uint8 operationState,,,,,,,,) = _executor.rootMigrationOperationV1(operationId);
        (, uint8 authorityState, address candidateFactory,,,,,,) =
            _executor.rootMigrationAuthorityV1();
        assertEq(operationState, 3);
        assertEq(authorityState, 1);
        assertEq(candidateFactory, address(_factory));
    }

    function test_executeRootMigrationV1_RevertRollsBackCandidateOnBadReturnOrPoststate() external {
        _assertExecuteRollback(
            1, abi.encodeWithSelector(RootMigrationExecutorV1.InvalidFactoryStageReceipt.selector)
        );

        setUp();
        _assertExecuteRollback(
            2, abi.encodeWithSelector(RootMigrationExecutorV1.InvalidFactoryCampaignState.selector)
        );

        setUp();
        _assertExecuteRollback(
            3,
            abi.encodeWithSelector(
                LibRootBootstrapV1.BootstrapReturnLengthMismatch.selector,
                address(_factory),
                160,
                192
            )
        );
    }

    function test_executeRootMigrationV1_RevertWhen_DynamicAbiHasGapSuffixOrDirtyPadding()
        external
    {
        bytes32 operationId = _queue();
        bytes memory canonical = abi.encodeCall(
            IRootMigrationExecutorV1.executeRootMigrationV1,
            (operationId, address(_factory), _manifest)
        );
        assertEq(canonical.length, 1124);

        _assertExecutorRawRevert(
            bytes.concat(canonical, bytes32(0)),
            RootMigrationExecutorV1.NonCanonicalExecutorCalldata.selector
        );

        bytes memory dirtyPadding = canonical;
        dirtyPadding[dirtyPadding.length - 1] = 0x01;
        _assertExecutorRawRevert(
            dirtyPadding, RootMigrationExecutorV1.NonCanonicalExecutorCalldata.selector
        );

        _assertExecutorRawRevert(
            _gappedExecuteCalldata(operationId, address(_factory), _manifest),
            RootMigrationExecutorV1.NonCanonicalExecutorCalldata.selector
        );
    }

    function test_cancelAndExpire_UseExactAuthorityAndStrictExpiryEquality() external {
        bytes32 cancelled = _queue();
        vm.prank(_PROPOSER);
        _executor.cancelRootMigrationV1(cancelled);
        (, uint8 cancelledState,,,,,,,,) = _executor.rootMigrationOperationV1(cancelled);
        assertEq(cancelledState, 5);

        bytes32 expiring = _queue();
        (,,,,,,,,, uint64 executeBefore) = _executor.rootMigrationOperationV1(expiring);
        vm.warp(executeBefore);
        vm.expectRevert(RootMigrationExecutorV1.RootMigrationNotExpired.selector);
        _executor.expireRootMigrationV1(expiring);

        vm.warp(executeBefore + 1);
        _executor.expireRootMigrationV1(expiring);
        (, uint8 expiredState,,,,,,,,) = _executor.rootMigrationOperationV1(expiring);
        assertEq(expiredState, 6);
    }

    function test_confirmRootMigrationV1_AuthenticatesActiveCampaignAndSealsAuthority() external {
        bytes32 operationId = _queueAndStage();
        bytes32 receipt = keccak256("root-receipt");
        assertEq(_factory.activateAndConfirm(receipt), _RAC1);

        (, uint8 operationState,,,,,,,,) = _executor.rootMigrationOperationV1(operationId);
        assertEq(operationState, 4);
        (
            ,
            uint8 authorityState,
            address candidateFactory,,,
            address activeFactory,
            bytes32 activeOperationId,
            bytes32 activeCampaignKey,
            bytes32 activeReceipt
        ) = _executor.rootMigrationAuthorityV1();
        assertEq(authorityState, 2);
        assertEq(candidateFactory, address(0));
        assertEq(activeFactory, address(_factory));
        assertEq(activeOperationId, operationId);
        assertEq(activeCampaignKey, _factory.campaignKey());
        assertEq(activeReceipt, receipt);
    }

    function test_confirmRootMigrationV1_RevertWhen_PrcTimingBitmapOrReceiptChanges() external {
        _queueAndStage();
        (uint64 generation, uint64 expiresAt) = _factory.campaignTiming();
        bytes32 receipt = keccak256("root-receipt");

        _factory.setCampaignState(2, generation + 1, expiresAt, 0x01ff, receipt);
        vm.expectRevert(RootMigrationExecutorV1.InvalidFactoryCampaignState.selector);
        _factory.confirmCurrent(receipt);

        _factory.setCampaignState(2, generation, expiresAt + 1, 0x01ff, receipt);
        vm.expectRevert(RootMigrationExecutorV1.InvalidFactoryCampaignState.selector);
        _factory.confirmCurrent(receipt);

        _factory.setCampaignState(2, generation, expiresAt, 0x01fe, receipt);
        vm.expectRevert(RootMigrationExecutorV1.InvalidFactoryCampaignState.selector);
        _factory.confirmCurrent(receipt);

        _factory.setCampaignState(2, generation, expiresAt, 0x01ff, keccak256("wrong-receipt"));
        vm.expectRevert(RootMigrationExecutorV1.InvalidFactoryCampaignState.selector);
        _factory.confirmCurrent(receipt);
    }

    function test_clearAbortedRootMigrationV1_AuthenticatesAbortedCampaignAndReturnsIdle()
        external
    {
        bytes32 operationId = _queueAndStage();
        _factory.abortAndClear();

        (, uint8 operationState,,,,,,,,) = _executor.rootMigrationOperationV1(operationId);
        assertEq(operationState, 7);
        (, uint8 authorityState, address candidateFactory,,,,,,) =
            _executor.rootMigrationAuthorityV1();
        assertEq(authorityState, 0);
        assertEq(candidateFactory, address(0));
    }

    function test_clearAbortedRootMigrationV1_AllowsOnlyDeployedBitmapSubsetAndZeroReceipt()
        external
    {
        _queueAndStage();
        (uint64 generation, uint64 expiresAt) = _factory.campaignTiming();

        _factory.setCampaignState(3, generation, expiresAt, 0x0200, bytes32(0));
        vm.expectRevert(RootMigrationExecutorV1.InvalidFactoryCampaignState.selector);
        _factory.clearCurrent();

        _factory.setCampaignState(3, generation, expiresAt, 0x0101, keccak256("receipt"));
        vm.expectRevert(RootMigrationExecutorV1.InvalidFactoryCampaignState.selector);
        _factory.clearCurrent();

        _factory.setCampaignState(3, generation, expiresAt, 0x0101, bytes32(0));
        _factory.clearCurrent();
        (, uint8 authorityState,,,,,,,) = _executor.rootMigrationAuthorityV1();
        assertEq(authorityState, 0);
    }

    function _queue() private returns (bytes32 operationId_) {
        vm.prank(_PROPOSER);
        return _executor.queueRootMigrationV1(
            address(_factory), _manifestHash, address(_factory).codehash, _factoryConfig
        );
    }

    function _queueAndStage() private returns (bytes32 operationId_) {
        operationId_ = _queue();
        vm.warp(block.timestamp + _DELAY);
        _executor.executeRootMigrationV1(operationId_, address(_factory), _manifest);
    }

    function _assertExecuteRollback(uint8 _mode, bytes memory _expectedError) private {
        bytes32 operationId = _queue();
        _factory.setMode(_mode);
        vm.warp(block.timestamp + _DELAY);
        vm.expectRevert(_expectedError);
        _executor.executeRootMigrationV1(operationId, address(_factory), _manifest);

        (, uint8 operationState,,,,,,,,) = _executor.rootMigrationOperationV1(operationId);
        assertEq(operationState, 1);
        (, uint8 authorityState,,,,,,,) = _executor.rootMigrationAuthorityV1();
        assertEq(authorityState, 0);
    }

    function _assertExecutorRawRevert(
        bytes memory _calldata,
        bytes4 _expectedError
    )
        private
    {
        (bool success, bytes memory returndata) = address(_executor).call(_calldata);
        assertFalse(success);
        assertGe(returndata.length, 4);
        assertEq(bytes4(returndata), _expectedError);
    }

    function _deriveOperationId(uint64 _nonce) private view returns (bytes32 operationId_) {
        return keccak256(
            abi.encodePacked(
                "slot-chain-root-migration-operation-v1",
                block.chainid,
                address(_executor),
                _nonce,
                address(_factory),
                _manifestHash,
                address(_factory).codehash,
                _factoryConfig
            )
        );
    }

    function _deriveManifestHash(bytes memory _value) private pure returns (bytes32 hash_) {
        return
            keccak256(abi.encodePacked("slot-chain-protocol-root-manifest-v1", uint16(969), _value));
    }

    function _buildManifest(
        uint64 _generation,
        bytes32 _namespace
    )
        private
        view
        returns (bytes memory manifest_)
    {
        manifest_ = new bytes(969);
        manifest_[0] = 0x01;
        _writeWord(manifest_, 1, bytes32(block.chainid));
        _writeWord(manifest_, 33, bytes32(uint256(_generation) << 192));
        _writeWord(manifest_, 41, _namespace);
    }

    function _gappedExecuteCalldata(
        bytes32 _operationId,
        address _factoryAddress,
        bytes memory _value
    )
        private
        pure
        returns (bytes memory calldata_)
    {
        bytes memory padded = new bytes(992);
        for (uint256 i; i < _value.length; ++i) {
            padded[i] = _value[i];
        }
        return bytes.concat(
            IRootMigrationExecutorV1.executeRootMigrationV1.selector,
            _operationId,
            bytes32(uint256(uint160(_factoryAddress))),
            bytes32(uint256(128)),
            bytes32(0),
            bytes32(uint256(_value.length)),
            padded
        );
    }

    function _writeWord(bytes memory _value, uint256 _offset, bytes32 _word) private pure {
        assembly ("memory-safe") {
            mstore(add(add(_value, 32), _offset), _word)
        }
    }
}
