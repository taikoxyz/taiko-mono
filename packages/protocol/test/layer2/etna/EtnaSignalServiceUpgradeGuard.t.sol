// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {
    BuildEtnaReadinessL2Message,
    LibEtnaReadinessL2Message
} from "script/layer2/etna/BuildEtnaReadinessL2Message.s.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { EtnaSignalServiceUpgradeGuard } from "src/layer2/etna/EtnaSignalServiceUpgradeGuard.sol";
import { DelegateController } from "src/layer2/governance/DelegateController.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibBytes } from "src/shared/libs/LibBytes.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { Layer2Test } from "test/layer2/Layer2Test.sol";
import { LegacySignalService } from "test/shared/signal/LegacySignalService.sol";

/// @dev The readiness proposal's L2 message (Etna SWITCH.md section 3, ANCHORLESS.md section 8,
/// step 3), built by `LibEtnaReadinessL2Message` and relayed through the real L2 Bridge to the real
/// `DelegateController`. It upgrades a real `SignalService` proxy on the pre-Etna (flat layout)
/// implementation, whose syncer is a real `Anchor` proxy, with the canonical EIP-4788 contract
/// etched. Every failed check reverts the whole batch: the message stays retriable and the proxy
/// keeps its implementation.
contract EtnaSignalServiceUpgradeGuardTest is Layer2Test {
    uint64 private constant UNZEN_TIME = 1_800_000_000;
    uint64 private constant ETNA_TIME = 1_800_000_012;
    bytes32 private constant L1_STATE_ROOT = bytes32(uint256(0xa1));
    address private constant GOLDEN_TOUCH = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
    address private constant BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    address private constant SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
    /// @dev Runtime code of the canonical EIP-4788 contract, as deployed on Ethereum mainnet and
    /// installed by `script/layer2/build_etna_genesis.py`.
    bytes private constant BEACON_ROOTS_CODE =
        hex"3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff015500";
    /// @dev Answers every call with 32 zero bytes: a nonzero, non-canonical runtime whose read
    /// alone would pass.
    bytes private constant ZERO_ROOT_CODE = hex"5f5f5260205ff3";

    address private daoController = randAddress();
    address private l1SignalService = randAddress();

    Bridge private tBridge;
    DelegateController private tDelegateController;
    Anchor private tAnchor;
    address private tSignalService;
    address private preEtnaImpl;
    address private etnaImpl;
    EtnaSignalServiceUpgradeGuard private guard;
    uint64 private messageId;

    function setUpOnEthereum() internal override {
        register("bridge", daoController);
    }

    function setUpOnTaiko() internal override {
        SignalService bridgeSignals = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE")))), deployer
        );
        tBridge = deployBridge(
            address(
                new Bridge(address(resolver), address(bridgeSignals), address(0), address(0), false)
            )
        );
        tDelegateController =
            deployDelegateController(ethereumChainId, address(tBridge), daoController);
    }

    function setUp() public override {
        super.setUp();
        vm.chainId(taikoChainId);
        _deployAnchorAndSignalService();
        etnaImpl = address(new SignalService(address(tAnchor), l1SignalService, address(0), true));
        guard = new EtnaSignalServiceUpgradeGuard();
        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);
        vm.chainId(ethereumChainId);
    }

    // ---------------------------------------------------------------
    // Builder and guard constants
    // ---------------------------------------------------------------

    function test_buildActions_ChecksUpgradesAndChecksInThatOrder() external view {
        Controller.Action[] memory actions = _actions(preEtnaImpl, etnaImpl);

        assertEq(actions.length, 3);
        for (uint256 i; i < actions.length; ++i) {
            assertEq(actions[i].value, 0);
        }
        assertEq(actions[0].target, address(guard));
        assertEq(
            actions[0].data,
            abi.encodeCall(
                EtnaSignalServiceUpgradeGuard.checkBeforeUpgrade, (tSignalService, preEtnaImpl)
            )
        );
        assertEq(actions[1].target, tSignalService);
        assertEq(actions[1].data, abi.encodeWithSignature("upgradeTo(address)", etnaImpl));
        assertEq(actions[2].target, address(guard));
        assertEq(
            actions[2].data,
            abi.encodeCall(
                EtnaSignalServiceUpgradeGuard.checkAfterUpgrade,
                (tSignalService, etnaImpl, etnaImpl.codehash)
            )
        );
    }

    // ---------------------------------------------------------------
    // The checking builder
    // ---------------------------------------------------------------

    /// @dev The builder accepts the implementation `DeployShastaL2Contracts` deploys and returns
    /// `buildActions` with its code hash.
    function test_buildChecked_ReturnsTheMessageForTheDeployedImplementation() external {
        Controller.Action[] memory actions =
            new BuildEtnaReadinessL2Message().buildChecked(_inputs());
        assertEq(
            keccak256(abi.encode(actions)), keccak256(abi.encode(_actions(preEtnaImpl, etnaImpl)))
        );
    }

    /// @dev The syncer and remote have no getter; the builder compares the implementation's code
    /// with one rebuilt from the expected arguments, so each wrong immutable is refused.
    function test_buildChecked_RevertWhen_TheImplementationHasAnotherSyncer() external {
        _expectImplementationRefused(
            address(new SignalService(Bob, l1SignalService, address(0), true))
        );
    }

    function test_buildChecked_RevertWhen_TheImplementationHasAnotherRemote() external {
        _expectImplementationRefused(
            address(new SignalService(address(tAnchor), Bob, address(0), true))
        );
    }

    function test_buildChecked_RevertWhen_TheImplementationHasAnotherPauser() external {
        _expectImplementationRefused(
            address(new SignalService(address(tAnchor), l1SignalService, Bob, true))
        );
    }

    function test_buildChecked_RevertWhen_TheImplementationDoesNotUseBeaconRoots() external {
        _expectImplementationRefused(
            address(new SignalService(address(tAnchor), l1SignalService, address(0), false))
        );
    }

    function test_buildChecked_RevertWhen_TheGuardIsNotThisBuildsGuard() external {
        BuildEtnaReadinessL2Message.Inputs memory inputs = _inputs();
        inputs.guard = preEtnaImpl;
        BuildEtnaReadinessL2Message builder = new BuildEtnaReadinessL2Message();
        vm.expectRevert(BuildEtnaReadinessL2Message.UpgradeGuardMismatch.selector);
        builder.buildChecked(inputs);
    }

    function test_buildChecked_RevertWhen_TheProxyUsesAnotherImplementation() external {
        BuildEtnaReadinessL2Message.Inputs memory inputs = _inputs();
        inputs.preEtnaImpl = etnaImpl;
        BuildEtnaReadinessL2Message builder = new BuildEtnaReadinessL2Message();
        vm.expectRevert(BuildEtnaReadinessL2Message.PreEtnaImplementationMismatch.selector);
        builder.buildChecked(inputs);
    }

    function test_buildChecked_RevertWhen_TheAnchorSavesElsewhere() external {
        BuildEtnaReadinessL2Message.Inputs memory inputs = _inputs();
        inputs.anchor = address(guard);
        BuildEtnaReadinessL2Message builder = new BuildEtnaReadinessL2Message();
        vm.expectRevert(BuildEtnaReadinessL2Message.AnchorMismatch.selector);
        builder.buildChecked(inputs);
    }

    function test_beaconRootsCodeHash_IsTheCanonicalEip4788RuntimeHash() external view {
        assertEq(guard.BEACON_ROOTS(), BEACON_ROOTS);
        assertEq(guard.BEACON_ROOTS_CODE_HASH(), keccak256(BEACON_ROOTS_CODE));
        assertEq(
            guard.BEACON_ROOTS_CODE_HASH(),
            0xf57acd40259872606d76197ef052f3d35588dadf919ee1f0e3cb9b62d3f4b02c
        );
    }

    // ---------------------------------------------------------------
    // The message
    // ---------------------------------------------------------------

    /// @dev In a block before Etna the message installs the Etna implementation; the `Anchor`
    /// keeps saving checkpoints until the fork (vector 5.w) and saves none from then on (5.x).
    function test_readinessMessage_UpgradesTheSignalServiceInABlockBeforeEtna() external onTaiko {
        _unzenBlock(UNZEN_TIME);
        _assertStatus(_relay(_actions(preEtnaImpl, etnaImpl)), IBridge.Status.DONE);

        assertEq(EssentialContract(tSignalService).impl(), etnaImpl);
        assertTrue(SignalService(tSignalService).usesBeaconRoots());
        assertEq(tDelegateController.lastExecutionId(), 0);

        vm.prank(GOLDEN_TOUCH);
        tAnchor.anchorV4(_checkpoint(1000));
        assertEq(SignalService(tSignalService).getCheckpoint(1000).stateRoot, L1_STATE_ROOT);

        _etnaBlock(ETNA_TIME);
        vm.prank(address(tAnchor));
        vm.expectRevert(SignalService.SS_CHECKPOINTS_CLOSED.selector);
        SignalService(tSignalService).saveCheckpoint(_checkpoint(1001));
    }

    /// @dev A superseded message relayed after its replacement executed finds another
    /// implementation installed.
    function test_readinessMessage_RevertWhen_TheProxyNoLongerUsesThePreEtnaImplementation()
        external
        onTaiko
    {
        _unzenBlock(UNZEN_TIME);
        address replacementImpl =
            address(new SignalService(address(tAnchor), l1SignalService, address(0), true));
        Controller.Action[] memory superseded = _actions(preEtnaImpl, etnaImpl);
        _assertStatus(_relay(_actions(preEtnaImpl, replacementImpl)), IBridge.Status.DONE);

        _expectBatchReverts(
            superseded, EtnaSignalServiceUpgradeGuard.UnexpectedImplementation.selector
        );
        _assertStatus(_relay(superseded), IBridge.Status.RETRIABLE);
        assertEq(EssentialContract(tSignalService).impl(), replacementImpl);
    }

    /// @dev Vector 3.h: the upgrade cannot execute while EIP-4788 has no code on L2, or code
    /// other than the canonical runtime. Once the canonical contract is in place, the same
    /// message is retried.
    function test_readinessMessage_RevertWhen_Eip4788CodeIsMissingOrNotCanonical()
        external
        onTaiko
    {
        _unzenBlock(UNZEN_TIME);
        Controller.Action[] memory actions = _actions(preEtnaImpl, etnaImpl);

        vm.etch(BEACON_ROOTS, "");
        _expectBatchReverts(actions, EtnaSignalServiceUpgradeGuard.BeaconRootsCodeMismatch.selector);
        IBridge.Message memory message = _message(actions);
        _assertStatus(_relay(message), IBridge.Status.RETRIABLE);
        assertEq(EssentialContract(tSignalService).impl(), preEtnaImpl);

        vm.etch(BEACON_ROOTS, ZERO_ROOT_CODE);
        _expectBatchReverts(actions, EtnaSignalServiceUpgradeGuard.BeaconRootsCodeMismatch.selector);
        vm.prank(Bob);
        vm.expectRevert(Bridge.B_RETRY_FAILED.selector);
        tBridge.retryMessage(message, false);
        assertEq(EssentialContract(tSignalService).impl(), preEtnaImpl);

        vm.etch(BEACON_ROOTS, BEACON_ROOTS_CODE);
        vm.prank(Bob);
        tBridge.retryMessage(message, false);
        _assertStatus(tBridge.messageStatus(tBridge.hashMessage(message)), IBridge.Status.DONE);
        assertEq(EssentialContract(tSignalService).impl(), etnaImpl);
    }

    /// @dev Without the engine's EIP-4788 write for this block, the read reverts.
    function test_readinessMessage_RevertWhen_TheBlockRecordedNoEip4788Root() external onTaiko {
        _unzenBlock(UNZEN_TIME);
        vm.warp(UNZEN_TIME + 1);
        _expectRetriable(
            _actions(preEtnaImpl, etnaImpl), EtnaSignalServiceUpgradeGuard.NotBeforeEtna.selector
        );
    }

    /// @dev In an Etna block the upgraded `SignalService` would reject every checkpoint the
    /// `Anchor` saves, so the precondition requires a zero root for the current timestamp.
    function test_readinessMessage_RevertWhen_ExecutedInAnEtnaBlock() external onTaiko {
        _etnaBlock(ETNA_TIME);
        _expectRetriable(
            _actions(preEtnaImpl, etnaImpl), EtnaSignalServiceUpgradeGuard.NotBeforeEtna.selector
        );
    }

    /// @dev The upgrade installs an implementation other than the one the postcondition expects.
    function test_readinessMessage_RevertWhen_TheUpgradeInstallsAnotherImplementation()
        external
        onTaiko
    {
        _unzenBlock(UNZEN_TIME);
        Controller.Action[] memory actions = _actions(preEtnaImpl, etnaImpl);
        address otherImpl =
            address(new SignalService(address(tAnchor), l1SignalService, address(0), true));
        actions[1].data = abi.encodeWithSignature("upgradeTo(address)", otherImpl);
        _expectRetriable(actions, EtnaSignalServiceUpgradeGuard.UnexpectedImplementation.selector);
    }

    /// @dev Vector 5.v: an L2 implementation with `usesBeaconRoots` false, such as the L1
    /// configuration, never closes its checkpoint store.
    function test_readinessMessage_RevertWhen_TheNewImplementationDoesNotUseBeaconRoots()
        external
        onTaiko
    {
        _unzenBlock(UNZEN_TIME);
        address l1ConfiguredImpl =
            address(new SignalService(address(tAnchor), l1SignalService, address(0), false));
        _expectRetriable(
            _actions(preEtnaImpl, l1ConfiguredImpl),
            EtnaSignalServiceUpgradeGuard.BeaconRootsUnused.selector
        );
    }

    /// @dev The upgrade installs the expected address, but the postcondition pins another code
    /// hash than the one the implementation holds.
    function test_readinessMessage_RevertWhen_TheImplementationHasAnotherCodeHash()
        external
        onTaiko
    {
        _unzenBlock(UNZEN_TIME);
        address otherSyncer = address(new SignalService(Bob, l1SignalService, address(0), true));
        Controller.Action[] memory actions = LibEtnaReadinessL2Message.buildActions(
            address(guard), tSignalService, preEtnaImpl, etnaImpl, otherSyncer.codehash
        );
        _expectRetriable(actions, EtnaSignalServiceUpgradeGuard.UnexpectedCodeHash.selector);
    }

    /// @dev Upgrading before the precondition runs makes the precondition fail.
    function test_readinessMessage_RevertWhen_TheActionsAreReordered() external onTaiko {
        _unzenBlock(UNZEN_TIME);
        Controller.Action[] memory actions = _actions(preEtnaImpl, etnaImpl);
        (actions[0], actions[1]) = (actions[1], actions[0]);
        _expectRetriable(actions, EtnaSignalServiceUpgradeGuard.UnexpectedImplementation.selector);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Deploys a real `Anchor` proxy and a real `SignalService` proxy on the pre-Etna
    /// implementation that name each other, both owned by the `DelegateController`.
    function _deployAnchorAndSignalService() private {
        address signalService =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);
        Anchor anchorImpl = new Anchor(ICheckpointStore(signalService), ethereumChainId);
        tAnchor = Anchor(
            address(
                new ERC1967Proxy(
                    address(anchorImpl), abi.encodeCall(Anchor.init, (address(tDelegateController)))
                )
            )
        );
        preEtnaImpl = address(new LegacySignalService(address(tAnchor), l1SignalService));
        tSignalService = address(
            new ERC1967Proxy(
                preEtnaImpl,
                abi.encodeCall(LegacySignalService.init, (address(tDelegateController)))
            )
        );
        assertEq(tSignalService, signalService);
    }

    function _actions(
        address _preEtnaImpl,
        address _etnaImpl
    )
        private
        view
        returns (Controller.Action[] memory)
    {
        return LibEtnaReadinessL2Message.buildActions(
            address(guard), tSignalService, _preEtnaImpl, _etnaImpl, _etnaImpl.codehash
        );
    }

    /// @dev The builder's inputs for this deployment.
    function _inputs() private view returns (BuildEtnaReadinessL2Message.Inputs memory) {
        return BuildEtnaReadinessL2Message.Inputs({
            guard: address(guard),
            signalService: tSignalService,
            preEtnaImpl: preEtnaImpl,
            etnaImpl: etnaImpl,
            anchor: address(tAnchor),
            l1SignalService: l1SignalService
        });
    }

    /// @dev The builder refuses `_impl` as the Etna implementation.
    function _expectImplementationRefused(address _impl) private {
        BuildEtnaReadinessL2Message.Inputs memory inputs = _inputs();
        inputs.etnaImpl = _impl;
        BuildEtnaReadinessL2Message builder = new BuildEtnaReadinessL2Message();
        vm.expectRevert(BuildEtnaReadinessL2Message.SignalServiceImplementationMismatch.selector);
        builder.buildChecked(inputs);
    }

    /// @dev Expects the batch to revert with `_error`, through the `DelegateController`'s own
    /// execution, then relays it as a message: the message stays retriable, the proxy keeps the
    /// pre-Etna implementation and the execution ID does not move.
    function _expectRetriable(Controller.Action[] memory _actions_, bytes4 _error) private {
        _expectBatchReverts(_actions_, _error);
        _assertStatus(_relay(_actions_), IBridge.Status.RETRIABLE);
        assertEq(EssentialContract(tSignalService).impl(), preEtnaImpl);
        assertEq(tDelegateController.lastExecutionId(), 0);
    }

    function _expectBatchReverts(
        Controller.Action[] memory _actions_,
        bytes4 _error
    )
        private
    {
        vm.expectRevert(
            abi.encodeWithSelector(LibBytes.INNER_ERROR.selector, abi.encodeWithSelector(_error))
        );
        tDelegateController.dryrun(abi.encode(_actions_));
    }

    function _relay(Controller.Action[] memory _actions_) private returns (IBridge.Status) {
        return _relay(_message(_actions_));
    }

    function _relay(IBridge.Message memory _message_) private returns (IBridge.Status status_) {
        vm.prank(Bob);
        (status_,) = tBridge.processMessage(_message_, "");
        _assertStatus(tBridge.messageStatus(tBridge.hashMessage(_message_)), status_);
    }

    /// @dev The L1 DAO controller's message with execution ID 0, which has no next-ID dependency.
    function _message(Controller.Action[] memory _actions_)
        private
        returns (IBridge.Message memory message_)
    {
        message_.id = ++messageId;
        message_.from = daoController;
        message_.srcChainId = ethereumChainId;
        message_.destChainId = taikoChainId;
        message_.destOwner = Bob;
        message_.to = address(tDelegateController);
        message_.data = abi.encodeCall(
            DelegateController.onMessageInvocation,
            (abi.encodePacked(uint64(0), abi.encode(_actions_)))
        );
    }

    /// @dev Starts a block before Etna at `_timestamp`: its EIP-4788 call records a zero root.
    function _unzenBlock(uint64 _timestamp) private {
        _recordBeaconRoot(_timestamp, bytes32(0));
    }

    /// @dev Starts an Etna block at `_timestamp`: its EIP-4788 call records its anchor's root.
    function _etnaBlock(uint64 _timestamp) private {
        _recordBeaconRoot(_timestamp, L1_STATE_ROOT);
    }

    /// @dev Records `_root` for `_timestamp` the way the EIP-4788 system call does.
    function _recordBeaconRoot(uint64 _timestamp, bytes32 _root) private {
        vm.warp(_timestamp);
        vm.prank(SYSTEM_ADDRESS);
        (bool ok,) = BEACON_ROOTS.call(abi.encode(_root));
        assertTrue(ok, "beacon root not recorded");
    }

    function _checkpoint(uint48 _blockNumber)
        private
        pure
        returns (ICheckpointStore.Checkpoint memory)
    {
        return ICheckpointStore.Checkpoint({
            blockNumber: _blockNumber, blockHash: bytes32(uint256(1)), stateRoot: L1_STATE_ROOT
        });
    }

    function _assertStatus(IBridge.Status _actual, IBridge.Status _expected) private pure {
        assertEq(uint8(_actual), uint8(_expected), "message status");
    }
}
