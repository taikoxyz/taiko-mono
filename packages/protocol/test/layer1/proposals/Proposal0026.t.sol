// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Proposal0026Harness } from "./Proposal0026Harness.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Test } from "forge-std/src/Test.sol";
import { Proposal0026 } from "script/layer1/proposals/Proposal0026.s.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { Controller } from "src/shared/governance/Controller.sol";

/// @custom:security-contact security@taiko.xyz
contract Proposal0026Test is Test {
    address internal constant INBOX_NEW_IMPL = 0x1010101010101010101010101010101010101010;

    /// @dev The deployed implementation, written out as a literal rather than read back from
    /// `Proposal0026`, so an edit to the constant there cannot be mirrored here.
    address internal constant DEPLOYED_INBOX_IMPL = 0xA18431d42C8dF9778905fBEa912aCF1881b49D2e;

    Proposal0026Harness internal proposal;

    function setUp() external {
        proposal = new Proposal0026Harness();
    }

    function test_buildL1Actions_EncodesTheInboxUpgrade() external view {
        Controller.Action[] memory actions = proposal.exposedBuildL1Actions(INBOX_NEW_IMPL);

        assertEq(actions.length, 1);
        _assertUpgrades(actions[0], L1.INBOX, INBOX_NEW_IMPL);
    }

    function test_buildL1Actions_RevertsWhileTheImplementationIsMissing() external {
        vm.expectRevert(Proposal0026.ImplementationNotDeployed.selector);
        proposal.exposedBuildL1Actions(address(0));
    }

    function test_buildL2Actions_HasNoL2Leg() external view {
        (uint64 executionId, uint32 gasLimit, Controller.Action[] memory actions) =
            proposal.exposedBuildL2Actions();

        assertEq(executionId, 0);
        assertEq(gasLimit, 0);
        assertEq(actions.length, 0);
    }

    /// @dev Pins what the no-argument builder forwards, and with it the batch `BuildProposal`
    /// wraps: the encoding test above calls the parameterised overload directly and so bypasses
    /// the forwarding line entirely. The deployed address is the `DEPLOYED_INBOX_IMPL` literal
    /// rather than a read of `Proposal0026`, so an edit to that constant cannot be mirrored here.
    function test_buildL1Actions_UsesDeployedImplementation() external view {
        Controller.Action[] memory actions = proposal.exposedBuildAllActions();
        assertEq(actions.length, 1, "an L1-only proposal appends no bridge message");
        _assertUpgrades(actions[0], L1.INBOX, DEPLOYED_INBOX_IMPL);
    }

    /// @dev `Proposal0026.action.md` is the payload the DAO actually executes, and it is generated
    /// out-of-band by `P=0026 pnpm proposal`. Nothing else in the repository checks that it was
    /// regenerated after the proposal changed, so a stale file would present one set of actions
    /// for review while the code describes another. This compares the committed calldata against
    /// what the proposal builds right now. The implementation is deployed, so a missing file is a
    /// failure, not a placeholder phase to skip.
    function test_actionFileMatchesTheBuiltCalldata() external {
        string memory file = vm.readFile("script/layer1/proposals/Proposal0026.action.md");

        // Split on the label rather than on backtick position: the file is prettier-formatted by
        // the pre-commit hook, so line breaks are not stable but the label is.
        string[] memory afterLabel = vm.split(file, "- Calldata: `");
        assertEq(afterLabel.length, 2, "action file has no single Calldata line");
        string memory committedHex = vm.split(afterLabel[1], "`")[0];

        assertEq(
            vm.parseBytes(committedHex),
            abi.encode(proposal.exposedBuildAllActions()),
            "Proposal0026.action.md is stale -- regenerate with `P=0026 pnpm proposal`"
        );

        // The generated header names the contract the calldata must be submitted to.
        assertTrue(
            vm.contains(file, vm.toString(L1.DAO_CONTROLLER)),
            "action file targets the wrong contract"
        );
    }

    /// @dev What `DeployInboxUpgradeL1` deploys: `MainnetInbox` built from this tree with the live
    /// address immutables. Every field is pinned as a literal against the live proxy's
    /// `getConfig()`, read on 2026-09-12 at L1 block 25,961,507, so the sharing percentage is the
    /// one difference the upgrade ships, and a constant in `MainnetInbox.sol` that drifts from
    /// the live value fails here rather than at deployment.
    function test_mainnetInbox_MatchesTheLiveConfigExceptForBasefeeSharing() external {
        MainnetInbox impl = new MainnetInbox(
            L1.ZK_REQUIRED_VERIFIER,
            L1.PRECONF_WHITELIST,
            L1.PROVER_WHITELIST,
            L1.SIGNAL_SERVICE,
            L1.TAIKO_TOKEN
        );
        IInbox.Config memory config = impl.getConfig();

        assertEq(config.basefeeSharingPctg, 100, "the change this proposal ships");

        assertEq(config.proofVerifier, 0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec);
        assertEq(config.proposerChecker, 0xFD019460881e6EeC632258222393d5821029b2ac);
        assertEq(config.proverWhitelist, 0xEa798547d97e345395dA071a0D7ED8144CD612Ae);
        assertEq(config.signalService, 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C);
        assertEq(config.bondToken, 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800);
        assertEq(config.minBond, 0);
        assertEq(config.livenessBond, 0);
        assertEq(config.withdrawalDelay, 604_800);
        assertEq(config.provingWindow, 14_400);
        assertEq(config.permissionlessProvingDelay, 432_000);
        assertEq(config.maxProofSubmissionDelay, 180);
        assertEq(config.ringBufferSize, 21_600);
        assertEq(config.forcedInclusionDelay, 576);
        assertEq(config.forcedInclusionFeeInGwei, 1_000_000);
        assertEq(config.forcedInclusionFeeDoubleThreshold, 50);
        assertEq(config.permissionlessInclusionMultiplier, 160);
    }

    function _assertUpgrades(
        Controller.Action memory _action,
        address _proxy,
        address _newImpl
    )
        internal
        pure
    {
        assertEq(_action.target, _proxy);
        assertEq(_action.value, 0);
        assertEq(_action.data, abi.encodeCall(UUPSUpgradeable.upgradeTo, (_newImpl)));
    }
}
