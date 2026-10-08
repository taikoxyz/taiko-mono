// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Proposal0026Harness } from "./Proposal0026Harness.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Test } from "forge-std/src/Test.sol";
import { Proposal0026 } from "script/layer1/proposals/Proposal0026.s.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { Controller } from "src/shared/governance/Controller.sol";

/// @custom:security-contact security@taiko.xyz
contract Proposal0026Test is Test {
    address internal constant INBOX_NEW_IMPL = 0x1010101010101010101010101010101010101010;

    /// @dev The deployed implementation, written out as a literal rather than read back from
    /// `Proposal0026`, so an edit to the constant there cannot be mirrored here.
    address internal constant DEPLOYED_INBOX_IMPL = 0xA18431d42C8dF9778905fBEa912aCF1881b49D2e;

    address internal constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address internal constant SP1_RETH_VERIFIER = 0x73A0Db393ef87ce781ac7957bE10D6628432100F;
    address internal constant SGXGETH_VERIFIER = 0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee;
    address internal constant SGXRETH_VERIFIER = 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8;
    address internal constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;
    address internal constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;

    bytes32 internal constant OLD_RISC0_PROPOSAL_IMAGE_ID =
        0xd6ab71c22201c23ef512b706f2e2d720f6da1b559fb76834aa9d4e35276f6e10;
    bytes32 internal constant OLD_RISC0_AGGREGATION_IMAGE_ID =
        0xdd9b8abff96c409ae2418edfb51d893ea2bd10f4873a0226f17a6998c1afc1b7;
    bytes32 internal constant NEW_RISC0_PROPOSAL_IMAGE_ID =
        0x88712dad7dc78126ee7bb592282d3102569c706f1b9db80580a582e5ffd1dfb0;
    bytes32 internal constant NEW_RISC0_AGGREGATION_IMAGE_ID =
        0x04480b22e244d60165f3d0898bc61ea084d9c76221464a8a3c3343c74889040a;

    bytes32 internal constant OLD_SP1_PROPOSAL_VKEY_BN254 =
        0x0025425c22e827507428a3d9c7b0f89635be5462f34bb6780563e3d6086be7c7;
    bytes32 internal constant OLD_SP1_PROPOSAL_VKEY_HASH_BYTES =
        0x12a12e113a09d41d05147b387b0f89632df2a3174d2ed9e00ac7c7ac086be7c7;
    bytes32 internal constant OLD_SP1_AGGREGATION_VKEY_BN254 =
        0x0051ac1d9e8cfd4196e37f9cfefd08e9b0f7ce653bad4634cd1ee84b71ca3be6;
    bytes32 internal constant OLD_SP1_AGGREGATION_VKEY_HASH_BYTES =
        0x28d60ecf233f50655c6ff39f6fd08e9b07be73296eb518d31a3dd09671ca3be6;
    bytes32 internal constant NEW_SP1_PROPOSAL_VKEY_BN254 =
        0x0012b97234e59f2319d44202c7b093fed9c9a51b2068e38d26625c139d668c97;
    bytes32 internal constant NEW_SP1_PROPOSAL_VKEY_HASH_BYTES =
        0x095cb91a3967c8c63a8840587b093fed4e4d28d901a38e344cc4b8271d668c97;
    bytes32 internal constant NEW_SP1_AGGREGATION_VKEY_BN254 =
        0x0017912dfd72308e2e2cd4211b05ed73a97eb7f576816adec2606a37507de51e;
    bytes32 internal constant NEW_SP1_AGGREGATION_VKEY_HASH_BYTES =
        0x0bc896fe5c8c238b459a8423305ed73a4bf5bfab5a05ab7b04c0d46e507de51e;

    bytes32 internal constant OLD_SGXGETH_MR_ENCLAVE =
        0x5f7da556f3b75dcc71465030e1b7274e82df9e9120c0b3eaf5bb76246a514005;
    bytes32 internal constant OLD_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0x3564b6a30089fcb3e2f69c19b22d23f84ce148387cd7a15f5c1df165b2ae5847;
    bytes32 internal constant OLD_SGXRETH_EDMM_MR_ENCLAVE =
        0xae2c7b92b2a71238226cb624ecd1171b66bf943cc372314affca0e6748ccecdf;
    bytes32 internal constant NEW_SGXGETH_MR_ENCLAVE =
        0x8c23c79045b9b6bb827eab208e0fe58d7446a57a55f3dfc825c90e904953105b;
    bytes32 internal constant NEW_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0xfeabd725eb5bb621b5c6a5071d1702bcbe06a643b42a0db8f381d5bc07dd81bf;
    bytes32 internal constant NEW_SGXRETH_EDMM_MR_ENCLAVE =
        0x6f3c8c55ec62fe48b83e57463e8717aa9f8594418203c9520f0f80e6f4fc4d87;

    Proposal0026Harness internal proposal;

    function setUp() external {
        proposal = new Proposal0026Harness();
    }

    function test_buildL1Actions_EncodesInboxUpgradeAndVerifierRotation() external view {
        Controller.Action[] memory actions = proposal.exposedBuildL1Actions(INBOX_NEW_IMPL);

        assertEq(actions.length, 21);
        uint256 cursor;

        _assertUpgrades(actions[cursor++], L1.INBOX, INBOX_NEW_IMPL);

        _assertCall(
            actions[cursor++],
            RISC0_RETH_VERIFIER,
            abi.encodeCall(Risc0Verifier.setImageIdTrusted, (OLD_RISC0_PROPOSAL_IMAGE_ID, false))
        );
        _assertCall(
            actions[cursor++],
            RISC0_RETH_VERIFIER,
            abi.encodeCall(Risc0Verifier.setImageIdTrusted, (OLD_RISC0_AGGREGATION_IMAGE_ID, false))
        );
        _assertCall(
            actions[cursor++],
            RISC0_RETH_VERIFIER,
            abi.encodeCall(Risc0Verifier.setImageIdTrusted, (NEW_RISC0_PROPOSAL_IMAGE_ID, true))
        );
        _assertCall(
            actions[cursor++],
            RISC0_RETH_VERIFIER,
            abi.encodeCall(Risc0Verifier.setImageIdTrusted, (NEW_RISC0_AGGREGATION_IMAGE_ID, true))
        );

        bytes32[8] memory sp1VKeys = [
            OLD_SP1_PROPOSAL_VKEY_BN254,
            OLD_SP1_PROPOSAL_VKEY_HASH_BYTES,
            OLD_SP1_AGGREGATION_VKEY_BN254,
            OLD_SP1_AGGREGATION_VKEY_HASH_BYTES,
            NEW_SP1_PROPOSAL_VKEY_BN254,
            NEW_SP1_PROPOSAL_VKEY_HASH_BYTES,
            NEW_SP1_AGGREGATION_VKEY_BN254,
            NEW_SP1_AGGREGATION_VKEY_HASH_BYTES
        ];
        for (uint256 i; i < sp1VKeys.length; ++i) {
            _assertCall(
                actions[cursor++],
                SP1_RETH_VERIFIER,
                abi.encodeCall(SP1Verifier.setProgramTrusted, (sp1VKeys[i], i >= 4))
            );
        }

        _assertCall(
            actions[cursor++],
            SGXGETH_ATTESTER,
            abi.encodeCall(IProposal0026Attestation.setMrEnclave, (OLD_SGXGETH_MR_ENCLAVE, false))
        );
        _assertCall(
            actions[cursor++],
            SGXRETH_ATTESTER,
            abi.encodeCall(
                IProposal0026Attestation.setMrEnclave, (OLD_SGXRETH_NON_EDMM_MR_ENCLAVE, false)
            )
        );
        _assertCall(
            actions[cursor++],
            SGXRETH_ATTESTER,
            abi.encodeCall(
                IProposal0026Attestation.setMrEnclave, (OLD_SGXRETH_EDMM_MR_ENCLAVE, false)
            )
        );
        _assertCall(
            actions[cursor++],
            SGXGETH_ATTESTER,
            abi.encodeCall(IProposal0026Attestation.setMrEnclave, (NEW_SGXGETH_MR_ENCLAVE, true))
        );
        _assertCall(
            actions[cursor++],
            SGXRETH_ATTESTER,
            abi.encodeCall(
                IProposal0026Attestation.setMrEnclave, (NEW_SGXRETH_NON_EDMM_MR_ENCLAVE, true)
            )
        );
        _assertCall(
            actions[cursor++],
            SGXRETH_ATTESTER,
            abi.encodeCall(
                IProposal0026Attestation.setMrEnclave, (NEW_SGXRETH_EDMM_MR_ENCLAVE, true)
            )
        );

        uint256[] memory instanceIds = new uint256[](1);
        instanceIds[0] = 2;
        _assertCall(
            actions[cursor++],
            SGXGETH_VERIFIER,
            abi.encodeCall(IProposal0026SgxVerifier.deleteInstances, (instanceIds))
        );
        _assertCall(
            actions[cursor++],
            SGXRETH_VERIFIER,
            abi.encodeCall(IProposal0026SgxVerifier.deleteInstances, (instanceIds))
        );

        assertEq(cursor, actions.length);
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
        assertEq(actions.length, 21, "an L1-only proposal appends no bridge message");
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

    function _assertCall(
        Controller.Action memory _action,
        address _target,
        bytes memory _data
    )
        internal
        pure
    {
        assertEq(_action.target, _target);
        assertEq(_action.value, 0);
        assertEq(_action.data, _data);
    }
}

interface IProposal0026Attestation {
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external;
}

interface IProposal0026SgxVerifier {
    function deleteInstances(uint256[] calldata _ids) external;
}
