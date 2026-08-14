// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildDirectProposal.sol";

// Security council revamp: 9 -> 5 members, standard threshold 5/9 -> 3/5, emergency
// threshold 7/9 -> 4/5. See Proposal0020.md for the full specification.
//
// To print the actions to paste into the DAO UI: `P=0020 pnpm proposal`
// To dryrun the proposal on an L1 fork: `SENDER=<a member or agent> P=0020 pnpm proposal:dryrun:l1`
contract Proposal0020 is BuildDirectProposal {
    // All seat addresses live in LibL1Addrs ("Security Council seats" section): the new
    // independent seat L1.SC_GUSTAVO_GONZALEZ (EOA); the removed L1.SC_CHAINBOUND, L1.SC_HALBORN,
    // L1.SC_DREW_VAN_DER_WERFF, L1.SC_TONI_WAHRSTATTER, L1.SC_GATTACA; and the retained
    // L1.SC_TAIKO_LABS, L1.SC_L2BEAT, L1.SC_ARAGON, L1.SC_NETHERMIND (dryrun assertions only).
    //
    // IMPORTANT: SC_GUSTAVO_GONZALEZ is currently the encryption agent appointed by the
    // Taiko Labs seat. Before this proposal EXECUTES, Taiko Labs must appoint a
    // replacement agent (EncryptionRegistry.appointAgent from the Taiko Labs Safe). If it
    // is still appointed at execution time, the Taiko Labs seat is left without a valid
    // approver until Taiko Labs rotates: only the appointed agent may approve for a seat,
    // and once this address is listed as its own seat, its approvals credit that seat
    // instead. The dryrun simulates the rotation between creation and execution;
    // approvals on in-flight proposals are unaffected (approvals are recorded per seat
    // owner).

    // New thresholds. minSignerListLength must stay >= the emergency minApprovals (see
    // SignerList.Settings NatSpec); 4 preserves the current one-removal headroom pattern.
    uint16 public constant NEW_MIN_SIGNER_LIST_LENGTH = 4;
    uint16 public constant NEW_STANDARD_MIN_APPROVALS = 3;
    uint16 public constant NEW_EMERGENCY_MIN_APPROVALS = 4;

    // Unchanged settings, restated because updateMultisigSettings takes the full struct.
    // checkBaseline() asserts they are still current at dryrun time.
    uint32 public constant DESTINATION_PROPOSAL_DURATION = 864_000; // 10-day veto period
    uint32 public constant PROPOSAL_EXPIRATION_PERIOD = 1_209_600; // 14 days

    /// @dev Contract-enforced ordering: the minSignerListLength floor (currently 8) must
    /// drop before removeSigners, or action 3 reverts. Placing the threshold updates
    /// after the list reaches its final size is defensive: the new minApprovals (3, 4)
    /// satisfy the `<= addresslistLength()` check at every intermediate size.
    function buildDaoActions() internal pure override returns (Action[] memory actions_) {
        address[] memory toAdd = new address[](1);
        toAdd[0] = L1.SC_GUSTAVO_GONZALEZ;

        address[] memory toRemove = new address[](5);
        toRemove[0] = L1.SC_CHAINBOUND;
        toRemove[1] = L1.SC_HALBORN;
        toRemove[2] = L1.SC_DREW_VAN_DER_WERFF;
        toRemove[3] = L1.SC_TONI_WAHRSTATTER;
        toRemove[4] = L1.SC_GATTACA;

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
        // Housekeeping: prunes unlisted accounts from the EncryptionRegistry's account
        // enumeration. Their appointerOf/agent mappings persist; harmless, as an unlisted
        // appointer can never resolve for approvals.
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
            L1.SC_TAIKO_LABS,
            L1.SC_L2BEAT,
            L1.SC_ARAGON,
            L1.SC_NETHERMIND,
            L1.SC_CHAINBOUND,
            L1.SC_HALBORN,
            L1.SC_DREW_VAN_DER_WERFF,
            L1.SC_TONI_WAHRSTATTER,
            L1.SC_GATTACA
        ];
        for (uint256 i; i < current.length; ++i) {
            check(
                readBool(L1.DAO_SIGNER_LIST, "isListed(address)", current[i]),
                "expected current member not listed"
            );
        }
        check(
            !readBool(L1.DAO_SIGNER_LIST, "isListed(address)", L1.SC_GUSTAVO_GONZALEZ),
            "new member already listed"
        );
        check(L1.SC_GUSTAVO_GONZALEZ.code.length == 0, "new member is not an EOA");
    }

    /// @dev Models the mandatory out-of-band step: Taiko Labs releases SC_GUSTAVO_GONZALEZ
    /// as its encryption agent before the DAO executes the actions (the real rotation
    /// appoints a replacement agent instead of un-appointing).
    function simulatePreExecution() internal override {
        address appointer =
            readAddr(L1.DAO_ENCRYPTION_REGISTRY, "appointerOf(address)", L1.SC_GUSTAVO_GONZALEZ);
        if (appointer != address(0)) {
            console2.log(
                "simulating agent rotation: releasing SC_GUSTAVO_GONZALEZ, appointer:", appointer
            );
            vm.prank(appointer);
            (bool ok,) = L1.DAO_ENCRYPTION_REGISTRY
                .call(abi.encodeWithSignature("appointAgent(address)", appointer));
            check(ok, "simulated agent rotation reverted");
        }
    }

    function checkPostState() internal view override {
        check(readUint(L1.DAO_SIGNER_LIST, "addresslistLength()") == 5, "expected 5 members");

        address[5] memory listed = [
            L1.SC_TAIKO_LABS, L1.SC_L2BEAT, L1.SC_ARAGON, L1.SC_NETHERMIND, L1.SC_GUSTAVO_GONZALEZ
        ];
        for (uint256 i; i < listed.length; ++i) {
            check(
                readBool(L1.DAO_SIGNER_LIST, "isListed(address)", listed[i]),
                "retained/new member not listed"
            );
        }
        address[5] memory removed = [
            L1.SC_CHAINBOUND,
            L1.SC_HALBORN,
            L1.SC_DREW_VAN_DER_WERFF,
            L1.SC_TONI_WAHRSTATTER,
            L1.SC_GATTACA
        ];
        for (uint256 i; i < removed.length; ++i) {
            check(
                !readBool(L1.DAO_SIGNER_LIST, "isListed(address)", removed[i]),
                "removed member still listed"
            );
        }

        // Action 6 effect: every account still enumerated by the registry is a listed
        // signer, i.e. the removed members were pruned (their appointerOf/agent mappings
        // persist, as documented in Proposal0020.md).
        address[] memory registered = abi.decode(
            readRaw(L1.DAO_ENCRYPTION_REGISTRY, abi.encodeWithSignature("getRegisteredAccounts()")),
            (address[])
        );
        for (uint256 i; i < registered.length; ++i) {
            check(
                readBool(L1.DAO_SIGNER_LIST, "isListed(address)", registered[i]),
                string.concat("unlisted account still registered: ", vm.toString(registered[i]))
            );
        }

        // The invariant behind the mandatory rotation: once listed, SC_GUSTAVO_GONZALEZ must
        // not be any seat's appointed agent.
        check(
            readAddr(L1.DAO_ENCRYPTION_REGISTRY, "appointerOf(address)", L1.SC_GUSTAVO_GONZALEZ)
                == address(0),
            "SC_GUSTAVO_GONZALEZ still an appointed agent; Taiko Labs must rotate before execution"
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
