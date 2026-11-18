// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployEtnaSwitch } from "script/layer1/etna/DeployEtnaSwitch.s.sol";
import { DeployEtnaVerifiers } from "script/layer1/etna/DeployEtnaVerifiers.s.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxWithEtnaCutoffs } from "src/layer1/core/impl/InboxWithEtnaCutoffs.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { InboxTestBase } from "test/layer1/core/inbox/InboxTestBase.sol";

/// @dev Exercises the real scripts over a live Unzen Inbox and SignalService. No trust or
/// initialization is installed by the switching script; the DAO owns each new control surface.
contract DeployEtnaSwitchScenarios is InboxTestBase {
    uint256 private constant _DEPLOYER_KEY = 0xe7aa;
    uint48 private constant _FORK_TIME = 1_000_000;

    DeployEtnaSwitch private _switch;
    DeployEtnaVerifiers private _verifiers;

    function _buildConfig() internal override returns (IInbox.Config memory config_) {
        config_ = super._buildConfig();
        config_.proofVerifier =
            address(new ZkRequiredVerifier(address(0), address(0), address(0), address(0)));
    }

    /// @dev Called by the devnet script test in its serial environment-variable scenarios.
    function run() external {
        vm.pauseGasMetering();
        _switch = new DeployEtnaSwitch();
        _verifiers = new DeployEtnaVerifiers();
        _setEnvironment();

        _assertOwnerRequired("");
        _assertOwnerRequired(vm.toString(address(0)));
        vm.setEnv("CONTRACT_OWNER", vm.toString(address(this)));

        (address proxy, address retainedSignal) = _switch.deployInboxProxy();
        assertEq(retainedSignal, address(signalService));
        assertEq(EssentialContract(proxy).owner(), address(this));
        assertEq(EssentialContract(proxy).pendingOwner(), address(0));
        vm.setEnv("INBOX_PROXY", vm.toString(proxy));
        address registry = _switch.deployRegistry();
        vm.setEnv("STAKING_REGISTRY", vm.toString(registry));
        DeployEtnaVerifiers.VerifierAddresses memory verifiers = _verifiers.run();
        vm.setEnv("ETNA_PROOF_VERIFIER", vm.toString(verifiers.proofVerifier));
        address cutoff = address(new InboxWithEtnaCutoffs(inbox.getConfig(), _FORK_TIME, 12, 500));
        vm.setEnv("UNZEN_INBOX_IMPLEMENTATION", vm.toString(cutoff));

        address[5] memory controlled =
            [proxy, registry, verifiers.sgxReth, verifiers.risc0Reth, verifiers.sp1Reth];
        for (uint256 i; i < controlled.length; ++i) {
            assertEq(EssentialContract(controlled[i]).owner(), address(this));
            assertEq(EssentialContract(controlled[i]).pendingOwner(), address(0));
            uint256 snapshot = vm.snapshotState();
            EssentialContract(controlled[i]).transferOwnership(Bob);
            vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
            _switch.deployInbox();
            vm.prank(Bob);
            EssentialContract(controlled[i]).acceptOwnership();
            vm.expectRevert(DeployEtnaSwitch.SwitchIdentityMismatch.selector);
            _switch.deployInbox();
            assertTrue(vm.revertToState(snapshot));
        }

        address implementation = _switch.deployInbox();
        assertEq(EtnaInbox(implementation).stakingRegistry(), registry);
        assertEq(EtnaInbox(implementation).proofVerifier(), verifiers.proofVerifier);
        assertFalse(EtnaInbox(proxy).isInitialized());
        assertEq(EssentialContract(proxy).owner(), address(this));
    }

    function _assertOwnerRequired(string memory _value) private {
        vm.setEnv("CONTRACT_OWNER", _value);
        vm.expectRevert(bytes4(keccak256("ExplicitOwnerRequired()")));
        _switch.deployInboxProxy();
        vm.expectRevert(DeployEtnaVerifiers.InvalidOwner.selector);
        _verifiers.run();
    }

    function _setEnvironment() private {
        vm.setEnv("PRIVATE_KEY", vm.toString(_DEPLOYER_KEY));
        vm.setEnv("L1_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("L2_CHAIN_ID", "167001");
        vm.setEnv("UNZEN_INBOX", vm.toString(address(inbox)));
        vm.setEnv("SIGNAL_SERVICE", vm.toString(address(signalService)));
        vm.setEnv("ORIGIN_WRITER", vm.toString(Carol));
        vm.setEnv("ETNA_FORK_TIME", vm.toString(_FORK_TIME));
        vm.setEnv("REMOTE_SIGNAL_SERVICE", vm.toString(_switch.l2SignalServiceAddress(167_001)));
        vm.setEnv("TAIKO_TOKEN", vm.toString(address(bondToken)));
        vm.setEnv("REGISTRY_MIN_STAKE", "1000000000000000000000");
        vm.setEnv("REGISTRY_ACTIVATION_DELAY", "10");
        vm.setEnv("REGISTRY_EXIT_DELAY", "20");
        vm.setEnv("REGISTRY_WITHDRAWAL_DELAY", "30");
        vm.setEnv("SLASH_BOUNTY_BPS", "1000");
        vm.setEnv("REGISTRY_FORFEIT_BPS", "1000");
        vm.setEnv("SLASH_SINK", vm.toString(David));
        vm.setEnv("MAX_BATCH_BLOCKS", "1000");
        vm.setEnv("FORCED_INCLUSION_FEE_GWEI", "10000000");
        vm.setEnv("FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD", "50");
        vm.setEnv("PROTOCOL_FEE_RECIPIENT", vm.toString(Emma));
        vm.setEnv("DCAP_ATTESTATION", vm.toString(address(verifier)));
        vm.setEnv("SGX_REGISTRAR", vm.toString(address(0)));
        vm.setEnv("SGX_INSTANCE_VALIDITY_DELAY", "1");
        vm.setEnv("R0_GROTH16_VERIFIER", vm.toString(address(verifier)));
        vm.setEnv("SP1_PLONK_VERIFIER", vm.toString(address(verifier)));
        vm.deal(vm.addr(_DEPLOYER_KEY), 100 ether);
    }
}
