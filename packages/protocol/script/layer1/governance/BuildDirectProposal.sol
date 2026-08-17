// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Action, IMultisig } from "./IAragonGovernance.sol";
import "forge-std/src/Script.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";

/// @notice Base for DAO proposals whose actions the Aragon DAO executes directly — i.e.
/// changes to the governance stack itself (SignerList, multisig plugins,
/// EncryptionRegistry). Protocol changes executed via the DAO Controller use
/// `BuildProposal` instead; the controller holds no permissions on the Aragon contracts,
/// so its `Execute` path cannot carry these actions.
///
/// Such proposals are created on the Standard Multisig, usually via the Taiko DAO UI
/// (dao.taiko.xyz): the UI pins the metadata to IPFS and assembles the `createProposal`
/// call from actions pasted into its custom-action (calldata) form.
///
/// Modes (`MODE` env):
/// - `print`:    write `Proposal$P.action.md` — the actions to paste into the DAO UI.
///               If `METADATA_URI` is set, also emit the full `createProposal` calldata
///               for direct submission (requires pre-pinned metadata).
/// - `l1dryrun`: on a fork — run `checkBaseline()`, create the proposal as `SENDER`
///               (`APPROVE=true` additionally approves at creation; default false),
///               assert the stored proposal matches the built actions (`getProposal`),
///               run `simulatePreExecution()`, apply the actions as the DAO, then run
///               `checkPostState()`.
///
/// The print-mode direct-submission fallback always encodes `approveProposal = false`;
/// a direct submitter approves separately.
abstract contract BuildDirectProposal is Script {
    function run() external {
        string memory mode = vm.envString("MODE");
        if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("print"))) {
            logProposalAction(vm.envString("P"));
        } else if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("l1dryrun"))) {
            dryrunL1();
        } else {
            console2.log("Error: Invalid mode. Must be one of: print, l1dryrun");
            revert InvalidMode(mode);
        }
    }

    /// @dev The actions the DAO will execute, in order.
    function buildDaoActions() internal view virtual returns (Action[] memory);

    /// @dev Pre-creation assertions against the forked chain (dryrun only).
    function checkBaseline() internal view virtual { }

    /// @dev Out-of-band steps that must happen between proposal creation and DAO
    /// execution, simulated on the fork (dryrun only). Default: none.
    function simulatePreExecution() internal virtual { }

    /// @dev Post-execution assertions against the forked chain (dryrun only).
    function checkPostState() internal view virtual { }

    // ---------------------------------------------------------------
    // Mode implementations
    // ---------------------------------------------------------------

    function logProposalAction(string memory _proposalId) internal {
        Action[] memory actions = buildDaoActions();

        string memory fileName =
            string.concat("./script/layer1/proposals/Proposal", _proposalId, ".action.md");
        string memory fileContent = string.concat(
            "# Proposal",
            _proposalId,
            "\n\nCreated via the Taiko DAO UI on the Standard Multisig `",
            vm.toString(L1.DAO_STANDARD_MULTISIG),
            "`.\nThe UI pins the metadata and assembles `createProposal`; paste each action",
            " below into the\nUI's custom-action (calldata) form, in order. After creation,",
            " compare the actions\nstored on-chain against this file before approving (the",
            " `getProposal` command in\nProposal",
            _proposalId,
            ".md).\n\n",
            "- Destination plugin (set by the UI): `",
            vm.toString(L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN),
            "`\n"
        );

        for (uint256 i; i < actions.length; ++i) {
            fileContent = string.concat(
                fileContent,
                "\n## Action ",
                vm.toString(i + 1),
                "\n- To: `",
                vm.toString(actions[i].to),
                "` (",
                nameOf(actions[i].to),
                ")\n- Value: `",
                vm.toString(actions[i].value),
                "`\n- Data: `",
                vm.toString(actions[i].data),
                "`\n"
            );
        }

        // Fallback for submitting createProposal directly (not via the UI): requires a
        // pre-pinned METADATA_URI, since nothing pins the metadata for you outside the UI.
        string memory metadataURI = vm.envOr("METADATA_URI", string(""));
        if (bytes(metadataURI).length > 0) {
            fileContent = string.concat(
                fileContent,
                "\n## Direct submission fallback (bypassing the UI)\n- To (Standard Multisig): `",
                vm.toString(L1.DAO_STANDARD_MULTISIG),
                "`\n- Function: `createProposal`\n- Value: `0`\n- Metadata URI: `",
                metadataURI,
                "`\n- Calldata: `",
                vm.toString(buildCreateProposalCalldata(metadataURI)),
                "`\n"
            );
        }

        vm.writeFile(fileName, fileContent);
        console2.log(fileContent);
        console2.log("Proposal action details written to", fileName);
    }

    function dryrunL1() internal {
        checkBaseline();

        address sender = vm.envOr("SENDER", address(0));
        if (sender == address(0)) revert MissingEnv("SENDER");
        string memory metadataURI = vm.envOr("METADATA_URI", string("ipfs://dryrun-placeholder"));
        bool approve = vm.envOr("APPROVE", false);

        // Built before the prank: a subclass's buildDaoActions may make view calls, and
        // an external call inside the argument expression would consume the prank.
        Action[] memory actions = buildDaoActions();
        IMultisig multisig = IMultisig(L1.DAO_STANDARD_MULTISIG);
        vm.prank(sender);
        uint256 proposalId = multisig.createProposal(
            bytes(metadataURI), actions, L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN, approve
        );
        console2.log("createProposal accepted, proposalId:", proposalId);

        // Rehearses the approver-side check (the `getProposal` diff in Proposal$P.md):
        // what the multisig stored is exactly what buildDaoActions() built.
        (,,,, Action[] memory stored, address destinationPlugin) = multisig.getProposal(proposalId);
        check(
            destinationPlugin == L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN,
            "stored destination plugin differs"
        );
        check(stored.length == actions.length, "stored action count differs");
        for (uint256 i; i < stored.length; ++i) {
            check(
                stored[i].to == actions[i].to && stored[i].value == actions[i].value
                    && keccak256(stored[i].data) == keccak256(actions[i].data),
                string.concat("stored action ", vm.toString(i + 1), " differs")
            );
        }

        simulatePreExecution();

        for (uint256 i; i < actions.length; ++i) {
            check(
                actions[i].to.code.length > 0,
                string.concat("action ", vm.toString(i + 1), " target has no code")
            );
            vm.prank(L1.DAO);
            (bool ok, bytes memory ret) =
                actions[i].to.call{ value: actions[i].value }(actions[i].data);
            logIfReverted(ok, ret);
            check(ok, string.concat("action ", vm.toString(i + 1), " reverted"));
        }

        checkPostState();
        console2.log("Dryrun OK");
    }

    // ---------------------------------------------------------------
    // Helpers for subclasses
    // ---------------------------------------------------------------

    /// @dev The full `Multisig.createProposal` calldata for the direct-submission
    /// fallback (the DAO UI assembles this call itself, and the dryrun calls the typed
    /// interface). Always encodes `approveProposal = false`; a direct submitter
    /// approves separately.
    function buildCreateProposalCalldata(string memory _metadataURI)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            IMultisig.createProposal,
            (bytes(_metadataURI), buildDaoActions(), L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN, false)
        );
    }

    function logIfReverted(bool _ok, bytes memory _returnData) internal pure {
        if (!_ok) {
            console2.log("revert data:");
            console2.logBytes(_returnData);
        }
    }

    function check(bool _ok, string memory _what) internal pure {
        if (!_ok) revert CheckFailed(_what);
    }

    function nameOf(address _target) internal pure returns (string memory) {
        if (_target == L1.DAO_SIGNER_LIST) return "SignerList";
        if (_target == L1.DAO_STANDARD_MULTISIG) return "Standard Multisig";
        if (_target == L1.DAO_EMERGENCY_MULTISIG) return "Emergency Multisig";
        if (_target == L1.DAO_ENCRYPTION_REGISTRY) return "EncryptionRegistry";
        if (_target == L1.DAO) return "DAO";
        return "?";
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error MissingEnv(string name);
    error CheckFailed(string what);
    error InvalidMode(string mode);
}
