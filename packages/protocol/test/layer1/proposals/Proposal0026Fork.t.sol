// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Proposal0026Harness } from "./Proposal0026Harness.sol";
import { Test } from "forge-std/src/Test.sol";
import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { Controller } from "src/shared/governance/Controller.sol";

/// @notice Rehearses the Proposal0026 upgrade against a historical mainnet fork.
/// @dev Skipped unless `L1_FORK_URL` is set, because CI configures no RPC endpoints. Run with:
///
///   L1_FORK_URL=<l1 rpc> FOUNDRY_PROFILE=layer1 forge test --match-contract Proposal0026ForkTest -vv
///
/// Defaults to block 26,075,649, after Proposal0021 and the new inbox implementation deployment,
/// but before Proposal0026.
/// Set `L1_FORK_BLOCK` to use another pre-upgrade block with an archive RPC. `--fork-block-number`
/// does not select the block of the fork this test creates.
///
/// `Proposal0026.t.sol` proves the proposal encodes the right calldata and that the new
/// implementation's configuration differs from the live one only in the sharing percentage. This
/// rehearsal proves the upgrade itself against the live proxy: the DAO controller can perform it,
/// and afterwards the proxy answers the new percentage while everything it stores — core state,
/// proposal hashes, the forced-inclusion queue, owner, activation timestamp and initializer
/// version — reads exactly as before.
///
/// The rehearsal executes exactly what the DAO will: the calldata `Proposal0026` builds from its
/// constant, against the implementation that constant names, which already exists on mainnet.
/// Nothing is deployed by the test.
/// @custom:security-contact security@taiko.xyz
contract Proposal0026ForkTest is Test {
    /// @dev Live values read before the upgrade, compared against afterwards.
    struct Before {
        IInbox.Config config;
        IInbox.CoreState coreState;
        uint48 activationTimestamp;
        address owner;
        // The proxy's storage slot 0, whose lowest byte is the initializer version.
        bytes32 slot0;
        uint48 forcedInclusionHead;
        uint48 forcedInclusionTail;
        uint64 forcedInclusionFee;
        bytes32 lastProposalHash;
        bytes32 lastFinalizedProposalHash;
    }

    /// @dev EIP-1967 implementation slot.
    bytes32 private constant _IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The implementation the proxy must still be running when the rehearsal starts (Unzen,
    /// Proposal0019). Rejects an override taken after Proposal0026 executes, which would otherwise
    /// rehearse current -> current instead of the intended transition.
    address private constant _LIVE_INBOX_IMPL = 0x5253D4C91e80b880DdB54B78E74082Abe066F6b9;

    /// @dev Recorded post-Proposal0021, pre-Proposal0026 mainnet state.
    uint256 private constant _DEFAULT_L1_FORK_BLOCK = 26_075_649;

    bytes32 private constant _OLD_RISC0_PROPOSAL_IMAGE_ID =
        0xd6ab71c22201c23ef512b706f2e2d720f6da1b559fb76834aa9d4e35276f6e10;
    bytes32 private constant _OLD_RISC0_AGGREGATION_IMAGE_ID =
        0xdd9b8abff96c409ae2418edfb51d893ea2bd10f4873a0226f17a6998c1afc1b7;
    bytes32 private constant _NEW_RISC0_PROPOSAL_IMAGE_ID =
        0x88712dad7dc78126ee7bb592282d3102569c706f1b9db80580a582e5ffd1dfb0;
    bytes32 private constant _NEW_RISC0_AGGREGATION_IMAGE_ID =
        0x04480b22e244d60165f3d0898bc61ea084d9c76221464a8a3c3343c74889040a;

    bytes32 private constant _OLD_SP1_PROPOSAL_VKEY_BN254 =
        0x0025425c22e827507428a3d9c7b0f89635be5462f34bb6780563e3d6086be7c7;
    bytes32 private constant _OLD_SP1_PROPOSAL_VKEY_HASH_BYTES =
        0x12a12e113a09d41d05147b387b0f89632df2a3174d2ed9e00ac7c7ac086be7c7;
    bytes32 private constant _OLD_SP1_AGGREGATION_VKEY_BN254 =
        0x0051ac1d9e8cfd4196e37f9cfefd08e9b0f7ce653bad4634cd1ee84b71ca3be6;
    bytes32 private constant _OLD_SP1_AGGREGATION_VKEY_HASH_BYTES =
        0x28d60ecf233f50655c6ff39f6fd08e9b07be73296eb518d31a3dd09671ca3be6;
    bytes32 private constant _NEW_SP1_PROPOSAL_VKEY_BN254 =
        0x0012b97234e59f2319d44202c7b093fed9c9a51b2068e38d26625c139d668c97;
    bytes32 private constant _NEW_SP1_PROPOSAL_VKEY_HASH_BYTES =
        0x095cb91a3967c8c63a8840587b093fed4e4d28d901a38e344cc4b8271d668c97;
    bytes32 private constant _NEW_SP1_AGGREGATION_VKEY_BN254 =
        0x0017912dfd72308e2e2cd4211b05ed73a97eb7f576816adec2606a37507de51e;
    bytes32 private constant _NEW_SP1_AGGREGATION_VKEY_HASH_BYTES =
        0x0bc896fe5c8c238b459a8423305ed73a4bf5bfab5a05ab7b04c0d46e507de51e;

    bytes32 private constant _OLD_SGXGETH_MR_ENCLAVE =
        0x5f7da556f3b75dcc71465030e1b7274e82df9e9120c0b3eaf5bb76246a514005;
    bytes32 private constant _OLD_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0x3564b6a30089fcb3e2f69c19b22d23f84ce148387cd7a15f5c1df165b2ae5847;
    bytes32 private constant _OLD_SGXRETH_EDMM_MR_ENCLAVE =
        0xae2c7b92b2a71238226cb624ecd1171b66bf943cc372314affca0e6748ccecdf;
    bytes32 private constant _NEW_SGXGETH_MR_ENCLAVE =
        0x8c23c79045b9b6bb827eab208e0fe58d7446a57a55f3dfc825c90e904953105b;
    bytes32 private constant _NEW_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0xfeabd725eb5bb621b5c6a5071d1702bcbe06a643b42a0db8f381d5bc07dd81bf;
    bytes32 private constant _NEW_SGXRETH_EDMM_MR_ENCLAVE =
        0x6f3c8c55ec62fe48b83e57463e8717aa9f8594418203c9520f0f80e6f4fc4d87;

    error ActionReverted(uint256 index);

    function test_l1_upgradesAgainstLiveState() external {
        if (!_forkOrSkip("L1_FORK_URL")) return;

        assertEq(
            _implementationOf(L1.INBOX),
            _LIVE_INBOX_IMPL,
            "L1 fork is not pre-upgrade; set L1_FORK_BLOCK=26075649 with an archive RPC"
        );

        Before memory before = _snapshot();
        assertEq(before.config.basefeeSharingPctg, 75, "forked inbox does not share 75");
        assertEq(before.owner, L1.DAO_CONTROLLER, "inbox is not owned by the DAO controller");
        assertEq(uint8(uint256(before.slot0)), 3, "inbox initializer version is not 3");
        _assertRotationState(true, false, true);

        (address newImpl, Controller.Action[] memory actions) = _implementationAndBatch();
        assertGt(newImpl.code.length, 0, "inbox implementation is not deployed");
        assertEq(actions.length, 21);

        // Execute the complete batch the way the DAO controller will, from the controller that
        // owns every target.
        _executeAs(L1.DAO_CONTROLLER, actions);

        assertEq(_implementationOf(L1.INBOX), newImpl);
        _assertOnlyTheSharingPercentageChanged(before);
        _assertRotationState(false, true, false);
    }

    /// @dev The check `P=0026 pnpm proposal:dryrun:l1` performs: the DAO controller executes the
    /// batch itself and reverts `DryrunSucceeded`. `dryrun` is permissionless, so no prank.
    function test_l1_dryrunSucceeds() external {
        if (!_forkOrSkip("L1_FORK_URL")) return;

        assertEq(
            _implementationOf(L1.INBOX),
            _LIVE_INBOX_IMPL,
            "L1 fork is not pre-upgrade; set L1_FORK_BLOCK=26075649 with an archive RPC"
        );

        Before memory before = _snapshot();
        (address sgxGethInstanceBefore,) =
            IProposal0026ForkSgxVerifier(L1.SGXGETH_VERIFIER).instances(2);
        (address sgxRethInstanceBefore,) =
            IProposal0026ForkSgxVerifier(L1.SGXRETH_VERIFIER).instances(2);
        (, Controller.Action[] memory actions) = _implementationAndBatch();
        assertEq(actions.length, 21);
        _assertRotationState(true, false, true);

        vm.expectRevert(Controller.DryrunSucceeded.selector);
        Controller(payable(L1.DAO_CONTROLLER)).dryrun(abi.encode(actions));

        assertEq(_implementationOf(L1.INBOX), _LIVE_INBOX_IMPL, "dryrun left the proxy upgraded");
        _assertInboxUnchanged(before);
        _assertRotationState(true, false, true);
        (address sgxGethInstanceAfter,) =
            IProposal0026ForkSgxVerifier(L1.SGXGETH_VERIFIER).instances(2);
        (address sgxRethInstanceAfter,) =
            IProposal0026ForkSgxVerifier(L1.SGXRETH_VERIFIER).instances(2);
        assertEq(sgxGethInstanceAfter, sgxGethInstanceBefore, "dryrun deleted SGX-geth instance");
        assertEq(sgxRethInstanceAfter, sgxRethInstanceBefore, "dryrun deleted SGX-reth instance");
    }

    /// @dev The implementation the batch upgrades to, as the proposal names it, and the committed
    /// batch: what `Proposal0026.action.md` carries.
    /// @return impl_ The implementation.
    /// @return actions_ The batch.
    function _implementationAndBatch()
        private
        returns (address impl_, Controller.Action[] memory actions_)
    {
        Proposal0026Harness harness = new Proposal0026Harness();
        impl_ = harness.MAINNET_INBOX_NEW_IMPL();
        actions_ = harness.exposedBuildAllActions();
    }

    /// @dev Reads everything the upgrade must leave alone, plus the configuration.
    /// @return before_ The live values.
    function _snapshot() private view returns (Before memory before_) {
        Inbox inbox = Inbox(L1.INBOX);

        before_.config = inbox.getConfig();
        before_.coreState = inbox.getCoreState();
        before_.activationTimestamp = inbox.activationTimestamp();
        before_.owner = inbox.owner();
        before_.slot0 = vm.load(L1.INBOX, bytes32(0));
        (before_.forcedInclusionHead, before_.forcedInclusionTail) =
            IForcedInclusionStore(L1.INBOX).getForcedInclusionState();
        before_.forcedInclusionFee = inbox.getCurrentForcedInclusionFee();
        before_.lastProposalHash = inbox.getProposalHash(before_.coreState.nextProposalId - 1);
        before_.lastFinalizedProposalHash =
            inbox.getProposalHash(before_.coreState.lastFinalizedProposalId);
    }

    /// @dev After the upgrade the proxy answers the new percentage, the same configuration
    /// otherwise, and the same storage.
    /// @param _before The values read before the upgrade.
    function _assertOnlyTheSharingPercentageChanged(Before memory _before) private view {
        Inbox inbox = Inbox(L1.INBOX);

        IInbox.Config memory config = inbox.getConfig();
        assertEq(config.basefeeSharingPctg, 100);
        config.basefeeSharingPctg = _before.config.basefeeSharingPctg;
        assertEq(
            abi.encode(config),
            abi.encode(_before.config),
            "configuration changed beyond the sharing percentage"
        );

        assertEq(abi.encode(inbox.getCoreState()), abi.encode(_before.coreState));
        assertEq(inbox.activationTimestamp(), _before.activationTimestamp);
        assertEq(inbox.owner(), _before.owner);
        assertEq(vm.load(L1.INBOX, bytes32(0)), _before.slot0, "initializer version moved");

        (uint48 head, uint48 tail) = IForcedInclusionStore(L1.INBOX).getForcedInclusionState();
        assertEq(head, _before.forcedInclusionHead);
        assertEq(tail, _before.forcedInclusionTail);
        assertEq(inbox.getCurrentForcedInclusionFee(), _before.forcedInclusionFee);

        assertEq(
            inbox.getProposalHash(_before.coreState.nextProposalId - 1), _before.lastProposalHash
        );
        assertEq(
            inbox.getProposalHash(_before.coreState.lastFinalizedProposalId),
            _before.lastFinalizedProposalHash
        );
    }

    /// @dev Checks all state mutated by the verifier-rotation leg. The expected values are
    /// independent literals rather than values read from the proposal contract.
    function _assertRotationState(
        bool _oldTrusted,
        bool _newTrusted,
        bool _instance2Active
    )
        private
        view
    {
        Risc0Verifier risc0 = Risc0Verifier(L1.RISC0_RETH_VERIFIER);
        assertEq(risc0.isImageTrusted(_OLD_RISC0_PROPOSAL_IMAGE_ID), _oldTrusted);
        assertEq(risc0.isImageTrusted(_OLD_RISC0_AGGREGATION_IMAGE_ID), _oldTrusted);
        assertEq(risc0.isImageTrusted(_NEW_RISC0_PROPOSAL_IMAGE_ID), _newTrusted);
        assertEq(risc0.isImageTrusted(_NEW_RISC0_AGGREGATION_IMAGE_ID), _newTrusted);

        SP1Verifier sp1 = SP1Verifier(L1.SP1_RETH_VERIFIER);
        assertEq(sp1.isProgramTrusted(_OLD_SP1_PROPOSAL_VKEY_BN254), _oldTrusted);
        assertEq(sp1.isProgramTrusted(_OLD_SP1_PROPOSAL_VKEY_HASH_BYTES), _oldTrusted);
        assertEq(sp1.isProgramTrusted(_OLD_SP1_AGGREGATION_VKEY_BN254), _oldTrusted);
        assertEq(sp1.isProgramTrusted(_OLD_SP1_AGGREGATION_VKEY_HASH_BYTES), _oldTrusted);
        assertEq(sp1.isProgramTrusted(_NEW_SP1_PROPOSAL_VKEY_BN254), _newTrusted);
        assertEq(sp1.isProgramTrusted(_NEW_SP1_PROPOSAL_VKEY_HASH_BYTES), _newTrusted);
        assertEq(sp1.isProgramTrusted(_NEW_SP1_AGGREGATION_VKEY_BN254), _newTrusted);
        assertEq(sp1.isProgramTrusted(_NEW_SP1_AGGREGATION_VKEY_HASH_BYTES), _newTrusted);

        IProposal0026ForkAttestation sgxGethAttester =
            IProposal0026ForkAttestation(L1.SGXGETH_ATTESTER);
        IProposal0026ForkAttestation sgxRethAttester =
            IProposal0026ForkAttestation(L1.SGXRETH_ATTESTER);
        assertEq(sgxGethAttester.trustedUserMrEnclave(_OLD_SGXGETH_MR_ENCLAVE), _oldTrusted);
        assertEq(
            sgxRethAttester.trustedUserMrEnclave(_OLD_SGXRETH_NON_EDMM_MR_ENCLAVE), _oldTrusted
        );
        assertEq(sgxRethAttester.trustedUserMrEnclave(_OLD_SGXRETH_EDMM_MR_ENCLAVE), _oldTrusted);
        assertEq(sgxGethAttester.trustedUserMrEnclave(_NEW_SGXGETH_MR_ENCLAVE), _newTrusted);
        assertEq(
            sgxRethAttester.trustedUserMrEnclave(_NEW_SGXRETH_NON_EDMM_MR_ENCLAVE), _newTrusted
        );
        assertEq(sgxRethAttester.trustedUserMrEnclave(_NEW_SGXRETH_EDMM_MR_ENCLAVE), _newTrusted);

        (address sgxGethInstance,) = IProposal0026ForkSgxVerifier(L1.SGXGETH_VERIFIER).instances(2);
        (address sgxRethInstance,) = IProposal0026ForkSgxVerifier(L1.SGXRETH_VERIFIER).instances(2);
        assertEq(sgxGethInstance != address(0), _instance2Active);
        assertEq(sgxRethInstance != address(0), _instance2Active);
    }

    /// @dev Verifies a reverted dryrun restored the complete inbox snapshot.
    function _assertInboxUnchanged(Before memory _before) private view {
        Inbox inbox = Inbox(L1.INBOX);
        assertEq(abi.encode(inbox.getConfig()), abi.encode(_before.config));
        assertEq(abi.encode(inbox.getCoreState()), abi.encode(_before.coreState));
        assertEq(inbox.activationTimestamp(), _before.activationTimestamp);
        assertEq(inbox.owner(), _before.owner);
        assertEq(vm.load(L1.INBOX, bytes32(0)), _before.slot0);

        (uint48 head, uint48 tail) = IForcedInclusionStore(L1.INBOX).getForcedInclusionState();
        assertEq(head, _before.forcedInclusionHead);
        assertEq(tail, _before.forcedInclusionTail);
        assertEq(inbox.getCurrentForcedInclusionFee(), _before.forcedInclusionFee);
        assertEq(
            inbox.getProposalHash(_before.coreState.nextProposalId - 1), _before.lastProposalHash
        );
        assertEq(
            inbox.getProposalHash(_before.coreState.lastFinalizedProposalId),
            _before.lastFinalizedProposalHash
        );
    }

    /// @dev Executes `_actions` one by one from `_controller`, the way `Controller._executeActions`
    /// does, aborting on the first failure. The failure is a custom error rather than an assertion
    /// with a concatenated message: this helper has a single caller, so the via-IR build of the
    /// `layer1o` profile inlines it into the test, and the message's temporaries pushed the loop
    /// one slot past the stack limit there.
    /// @param _controller The controller that executes the batch.
    /// @param _actions The actions.
    function _executeAs(address _controller, Controller.Action[] memory _actions) private {
        for (uint256 i; i < _actions.length; ++i) {
            vm.prank(_controller);
            (bool success,) = _actions[i].target.call{ value: _actions[i].value }(_actions[i].data);
            require(success, ActionReverted(i));
        }
    }

    /// @dev Selects a fork at `L1_FORK_BLOCK` (or the recorded pre-upgrade block), or marks the
    /// test skipped when the RPC URL is unset.
    /// @param _envVar Name of the environment variable holding the RPC URL.
    /// @return forked_ True when a fork was selected and the test should continue.
    function _forkOrSkip(string memory _envVar) private returns (bool forked_) {
        string memory url = vm.envOr(_envVar, string(""));
        if (bytes(url).length == 0) {
            vm.skip(true, string.concat(_envVar, " is not set"));
            return false;
        }
        uint256 forkBlock = vm.envOr("L1_FORK_BLOCK", _DEFAULT_L1_FORK_BLOCK);
        vm.createSelectFork(url, forkBlock);
        return true;
    }

    /// @dev Reads a proxy's EIP-1967 implementation slot.
    /// @param _proxy The proxy to read.
    /// @return impl_ The implementation address it delegates to.
    function _implementationOf(address _proxy) private view returns (address impl_) {
        impl_ = address(uint160(uint256(vm.load(_proxy, _IMPL_SLOT))));
    }
}

interface IProposal0026ForkAttestation {
    function trustedUserMrEnclave(bytes32 _mrEnclave) external view returns (bool);
}

interface IProposal0026ForkSgxVerifier {
    function instances(uint256 _id) external view returns (address addr_, uint64 validSince_);
}
