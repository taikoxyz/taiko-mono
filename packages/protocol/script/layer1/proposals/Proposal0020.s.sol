// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildDirectProposal.sol";

// Security council revamp: 9 -> 5 members, standard threshold 5/9 -> 3/5, emergency
// threshold 7/9 -> 4/5. See Proposal0020.md for the full specification.
//
// To print the actions to paste into the DAO UI: `P=0020 pnpm proposal`
// To dryrun the proposal on an L1 fork: `SENDER=<a member or agent> P=0020 pnpm proposal:dryrun:l1`
// To verify the UI-created proposal before approving: `PROPOSAL_ID=<id> P=0020 pnpm proposal:verify`
contract Proposal0020 is BuildDirectProposal {
    // New member: Gustavo Gonzalez, independent seat (EOA).
    //
    // IMPORTANT: this address is currently the encryption agent appointed by the Taiko
    // Labs seat. Before this proposal EXECUTES, Taiko Labs must appoint a replacement
    // agent (EncryptionRegistry.appointAgent from the Taiko Labs Safe). If it is still
    // appointed at execution time, the Taiko Labs seat is left without a valid approver
    // until Taiko Labs rotates: only the appointed agent may approve for a seat, and once
    // this address is listed as its own seat, its approvals credit that seat instead.
    // The dryrun simulates the rotation between creation and execution; approvals on
    // in-flight proposals are unaffected (approvals are recorded per seat owner).
    address public constant NEW_MEMBER = 0xAC5898b0FFFd23F4Ef09F0E50Fa1bC4896eF7163;

    // Members removed by this proposal.
    address public constant CHAINBOUND = 0x436a1075099A145417EBFc74BBaC9605e3e4f1A7;
    address public constant HALBORN = 0x0F40268Ec0Dc8D88CF2f22E227A29a0b478b6351;
    address public constant DREW_VAN_DER_WERFF = 0x25d3E89bAcE2040Ed3aF7c4c7B505cfBB72fD6f1;
    address public constant TONI_WAHRSTATTER = 0xa384E224A3F3D664F43eBE33395eF0DCcE67e894;
    address public constant GATTACA = 0x6268d189E011Aa53A2f09A1FE159445BeB3d878E;

    // Members retained (used by the dryrun assertions only).
    address public constant TAIKO_LABS = 0xb47fE76aC588101BFBdA9E68F66433bA51E8029a;
    address public constant L2BEAT = 0xf1cF63589A1e012F9124182c9eAa36B5333e5f06;
    address public constant ARAGON = 0xb284810536C0dAB6A8e48153B58588A9B9e0F701;
    address public constant NETHERMIND = 0x5353c607e6eca6C63FEC5c6C0F5CC3a5348d5c95;

    // New thresholds. minSignerListLength must stay >= the emergency minApprovals (see
    // SignerList.Settings NatSpec); 4 preserves the current one-removal headroom pattern.
    uint16 public constant NEW_MIN_SIGNER_LIST_LENGTH = 4;
    uint16 public constant NEW_STANDARD_MIN_APPROVALS = 3;
    uint16 public constant NEW_EMERGENCY_MIN_APPROVALS = 4;

    // Unchanged settings, restated because updateMultisigSettings takes the full struct.
    // checkBaseline() asserts they are still current at dryrun time.
    uint32 public constant DESTINATION_PROPOSAL_DURATION = 864_000; // 10-day veto period
    uint32 public constant PROPOSAL_EXPIRATION_PERIOD = 1_209_600; // 14 days

    /// @dev Order is mandatory: the minSignerListLength floor (currently 8) must drop
    /// before removeSigners, and the threshold updates must come after the list reaches
    /// its final size (minApprovals is checked against the then-current list length).
    function buildDaoActions() internal pure override returns (Action[] memory actions_) {
        address[] memory toAdd = new address[](1);
        toAdd[0] = NEW_MEMBER;

        address[] memory toRemove = new address[](5);
        toRemove[0] = CHAINBOUND;
        toRemove[1] = HALBORN;
        toRemove[2] = DREW_VAN_DER_WERFF;
        toRemove[3] = TONI_WAHRSTATTER;
        toRemove[4] = GATTACA;

        actions_ = new Action[](6);
        actions_[0] = Action({
            to: L1.DAO_SIGNER_LIST,
            value: 0,
            data: abi.encodeWithSignature(
                "updateSettings((address,uint16))",
                L1.DAO_ENCRYPTION_REGISTRY,
                NEW_MIN_SIGNER_LIST_LENGTH
            )
        });
        actions_[1] = Action({
            to: L1.DAO_SIGNER_LIST,
            value: 0,
            data: abi.encodeWithSignature("addSigners(address[])", toAdd)
        });
        actions_[2] = Action({
            to: L1.DAO_SIGNER_LIST,
            value: 0,
            data: abi.encodeWithSignature("removeSigners(address[])", toRemove)
        });
        actions_[3] = Action({
            to: L1.DAO_STANDARD_MULTISIG,
            value: 0,
            data: abi.encodeWithSignature(
                "updateMultisigSettings((bool,uint16,uint32,address,uint32))",
                true, // onlyListed
                NEW_STANDARD_MIN_APPROVALS,
                DESTINATION_PROPOSAL_DURATION,
                L1.DAO_SIGNER_LIST,
                PROPOSAL_EXPIRATION_PERIOD
            )
        });
        actions_[4] = Action({
            to: L1.DAO_EMERGENCY_MULTISIG,
            value: 0,
            data: abi.encodeWithSignature(
                "updateMultisigSettings((bool,uint16,address,uint32))",
                true, // onlyListed
                NEW_EMERGENCY_MIN_APPROVALS,
                L1.DAO_SIGNER_LIST,
                PROPOSAL_EXPIRATION_PERIOD
            )
        });
        // Housekeeping: prunes the removed members' EncryptionRegistry entries.
        actions_[5] = Action({
            to: L1.DAO_ENCRYPTION_REGISTRY,
            value: 0,
            data: abi.encodeWithSignature("removeUnused()")
        });
    }

    /// @dev Asserts every value the actions restate as "unchanged" is still current, and
    /// pins the exact current membership so a stale address fails fast with a clear
    /// message instead of an opaque action revert.
    function checkBaseline() internal view override {
        check(readUint(L1.DAO_SIGNER_LIST, "addresslistLength()") == 9, "member count changed");
        (address encryptionRegistry, uint16 minSignerListLength) = readSignerListSettings();
        check(encryptionRegistry == L1.DAO_ENCRYPTION_REGISTRY, "encryptionRegistry changed");
        check(minSignerListLength == 8, "minSignerListLength changed");

        (
            bool stdOnlyListed,
            uint16 stdApprovals,
            uint32 stdDuration,
            address stdSignerList,
            uint32 stdExpiration
        ) = readStandardMultisigSettings();
        check(stdOnlyListed, "standard onlyListed changed");
        check(stdApprovals == 5, "standard minApprovals changed");
        check(stdSignerList == L1.DAO_SIGNER_LIST, "standard signerList changed");
        check(
            stdDuration == DESTINATION_PROPOSAL_DURATION
                && stdExpiration == PROPOSAL_EXPIRATION_PERIOD,
            "standard multisig durations drifted; recheck action 4"
        );

        (
            bool emergencyOnlyListed,
            uint16 emergencyApprovals,
            address emergencySignerList,
            uint32 emergencyExpiration
        ) = readEmergencyMultisigSettings();
        check(emergencyOnlyListed, "emergency onlyListed changed");
        check(emergencyApprovals == 7, "emergency minApprovals changed");
        check(emergencySignerList == L1.DAO_SIGNER_LIST, "emergency signerList changed");
        check(
            emergencyExpiration == PROPOSAL_EXPIRATION_PERIOD,
            "emergency expiration drifted; recheck action 5"
        );

        address[9] memory current = [
            TAIKO_LABS,
            L2BEAT,
            ARAGON,
            NETHERMIND,
            CHAINBOUND,
            HALBORN,
            DREW_VAN_DER_WERFF,
            TONI_WAHRSTATTER,
            GATTACA
        ];
        for (uint256 i; i < current.length; ++i) {
            check(
                readBool(L1.DAO_SIGNER_LIST, "isListed(address)", current[i]),
                "expected current member not listed"
            );
        }
        check(
            !readBool(L1.DAO_SIGNER_LIST, "isListed(address)", NEW_MEMBER),
            "new member already listed"
        );
    }

    /// @dev Models the mandatory out-of-band step: Taiko Labs releases NEW_MEMBER as its
    /// encryption agent before the DAO executes the actions (the real rotation appoints a
    /// replacement agent instead of un-appointing).
    function simulatePreExecution() internal override {
        address appointer = readAddr(L1.DAO_ENCRYPTION_REGISTRY, "appointerOf(address)", NEW_MEMBER);
        if (appointer != address(0)) {
            console2.log("simulating agent rotation: releasing NEW_MEMBER, appointer:", appointer);
            vm.prank(appointer);
            (bool ok,) = L1.DAO_ENCRYPTION_REGISTRY
                .call(abi.encodeWithSignature("appointAgent(address)", appointer));
            check(ok, "simulated agent rotation reverted");
        }
    }

    function checkPostState() internal view override {
        check(readUint(L1.DAO_SIGNER_LIST, "addresslistLength()") == 5, "expected 5 members");

        address[5] memory listed = [TAIKO_LABS, L2BEAT, ARAGON, NETHERMIND, NEW_MEMBER];
        for (uint256 i; i < listed.length; ++i) {
            check(
                readBool(L1.DAO_SIGNER_LIST, "isListed(address)", listed[i]),
                "retained/new member not listed"
            );
        }
        address[5] memory removed =
            [CHAINBOUND, HALBORN, DREW_VAN_DER_WERFF, TONI_WAHRSTATTER, GATTACA];
        for (uint256 i; i < removed.length; ++i) {
            check(
                !readBool(L1.DAO_SIGNER_LIST, "isListed(address)", removed[i]),
                "removed member still listed"
            );
        }

        // The invariant behind the mandatory rotation: once listed, NEW_MEMBER must not
        // be any seat's appointed agent.
        check(
            readAddr(L1.DAO_ENCRYPTION_REGISTRY, "appointerOf(address)", NEW_MEMBER) == address(0),
            "NEW_MEMBER still appointed as an agent; Taiko Labs must rotate before execution"
        );

        (address encryptionRegistry, uint16 minSignerListLength) = readSignerListSettings();
        check(encryptionRegistry == L1.DAO_ENCRYPTION_REGISTRY, "encryptionRegistry not preserved");
        check(minSignerListLength == NEW_MIN_SIGNER_LIST_LENGTH, "minSignerListLength not updated");

        (
            bool stdOnlyListed,
            uint16 stdApprovals,
            uint32 stdDuration,
            address stdSignerList,
            uint32 stdExpiration
        ) = readStandardMultisigSettings();
        check(stdApprovals == NEW_STANDARD_MIN_APPROVALS, "standard threshold not updated");
        check(
            stdOnlyListed && stdSignerList == L1.DAO_SIGNER_LIST
                && stdDuration == DESTINATION_PROPOSAL_DURATION
                && stdExpiration == PROPOSAL_EXPIRATION_PERIOD,
            "standard settings not preserved"
        );

        (
            bool emergencyOnlyListed,
            uint16 emergencyApprovals,
            address emergencySignerList,
            uint32 emergencyExpiration
        ) = readEmergencyMultisigSettings();
        check(emergencyApprovals == NEW_EMERGENCY_MIN_APPROVALS, "emergency threshold not updated");
        check(
            emergencyOnlyListed && emergencySignerList == L1.DAO_SIGNER_LIST
                && emergencyExpiration == PROPOSAL_EXPIRATION_PERIOD,
            "emergency settings not preserved"
        );
    }
}
