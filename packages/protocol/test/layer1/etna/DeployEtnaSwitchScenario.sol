// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { VmSafe } from "forge-std/src/Vm.sol";
import { DeployEtnaSwitch } from "script/layer1/etna/DeployEtnaSwitch.s.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { InboxTestBase } from "test/layer1/core/inbox/InboxTestBase.sol";

contract DeployEtnaSwitchScenario is InboxTestBase {
    uint256 private constant _DEPLOYER_PK = 0xe7aa;

    DeployEtnaSwitch private _deployment;
    EtnaInboxBootstrap private _etna;
    EtnaInboxBootstrap private _etnaImplementation;
    address private _scriptDeployer;

    function setUp() public override {
        super.setUp();
        _deployment = new DeployEtnaSwitch();
        _scriptDeployer = vm.addr(_DEPLOYER_PK);
        vm.deal(_scriptDeployer, 100 ether);
        _etnaImplementation = new EtnaInboxBootstrap();
        _etna = EtnaInboxBootstrap(
            address(
                new ERC1967Proxy(
                    address(_etnaImplementation),
                    abi.encodeCall(EtnaInboxBootstrap.init, (address(this)))
                )
            )
        );
        signalService.upgradeTo(
            address(
                new SignalService(
                    address(inbox), REMOTE_SIGNAL_SERVICE, Alice, address(0), address(0)
                )
            )
        );
    }

    /// @dev Called by DeployEtnaDevnetTest's serial deployment test because environment variables
    /// are process-wide. The live Unzen Inbox, SignalService and Etna bootstrap are real proxies.
    function run() external {
        setUp();
        _setEnvironment();
        address signalImplementation = signalService.impl();
        address unzenImplementation = inbox.impl();
        uint64 nonce = vm.getNonce(_scriptDeployer);
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 1, blockHash: bytes32(uint256(1)), stateRoot: bytes32(uint256(2))
        });
        vm.prank(address(inbox));
        signalService.saveCheckpoint(checkpoint);

        SignalService deployed = SignalService(_deployment.deploySignalServiceImplementation());

        assertEq(vm.getNonce(_scriptDeployer), nonce + 1, "only the implementation deployed");
        assertEq(deployed.VERSION(), 1, "checkpoint namespace preserved");
        assertEq(deployed.pauser(), Alice, "existing pauser preserved");
        assertEq(deployed.stateRootProvider(), address(0), "L1 reads local checkpoints");
        assertEq(deployed.unzenInbox(), address(inbox), "legacy Inbox preserved");
        assertEq(signalService.impl(), signalImplementation, "live SignalService not upgraded");
        assertEq(inbox.impl(), unzenImplementation, "live Unzen Inbox not upgraded");
        assertEq(_etna.impl(), address(_etnaImplementation), "Etna remains on its bootstrap");
        assertFalse(_etna.isInitialized(), "Etna not initialized");
        assertEq(signalService.getCheckpoint(1).stateRoot, checkpoint.stateRoot, "live store kept");

        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        vm.prank(address(this));
        deployed.saveCheckpoint(checkpoint);
        vm.prank(address(_etna));
        deployed.saveCheckpoint(checkpoint);
        assertEq(deployed.getCheckpoint(1).stateRoot, checkpoint.stateRoot, "Etna is the syncer");

        // The real bootstrap reports no Etna start, allowing the legacy Inbox to keep syncing.
        checkpoint.blockNumber = type(uint48).max;
        vm.prank(address(inbox));
        deployed.saveCheckpoint(checkpoint);
        assertEq(
            deployed.getCheckpoint(type(uint48).max).stateRoot,
            checkpoint.stateRoot,
            "legacy syncer allowed before start"
        );
        vm.prank(Alice);
        deployed.pause();
        assertTrue(deployed.paused(), "preserved pauser can pause");

        _expectInvalidInbox(address(inbox));
        _expectInvalidInbox(address(_etnaImplementation));
    }

    /// @dev Exports only the inputs consumed by the SignalService implementation deployment.
    function _setEnvironment() private {
        vm.setEnv("PRIVATE_KEY", vm.toString(_DEPLOYER_PK));
        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("UNZEN_INBOX", vm.toString(address(inbox)));
        vm.setEnv("SIGNAL_SERVICE", vm.toString(address(signalService)));
        vm.setEnv("INBOX_PROXY", vm.toString(address(_etna)));
        vm.setEnv("L2_CHAIN_ID", vm.toString(taikoChainId));
        vm.setEnv(
            "REMOTE_SIGNAL_SERVICE", vm.toString(_deployment.l2SignalServiceAddress(taikoChainId))
        );
    }

    /// @dev Identity validation must precede even private-key validation and startBroadcast.
    /// @param _inbox An Unzen proxy or a bare implementation, neither a valid Etna proxy.
    function _expectInvalidInbox(address _inbox) private {
        vm.setEnv("INBOX_PROXY", vm.toString(_inbox));
        vm.setEnv("PRIVATE_KEY", "0");
        uint64 nonce = vm.getNonce(_scriptDeployer);
        vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
        _deployment.deploySignalServiceImplementation();
        (VmSafe.CallerMode mode,,) = vm.readCallers();
        assertEq(uint256(mode), uint256(VmSafe.CallerMode.None), "broadcast never started");
        assertEq(vm.getNonce(_scriptDeployer), nonce, "nothing deployed");
    }
}
