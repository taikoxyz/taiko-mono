// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildDirectProposal.sol";
import {
    Action,
    IEmergencyMultisig,
    IEncryptionRegistry,
    IMultisig,
    ISignerList
} from "../governance/IAragonGovernance.sol";

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
    // IMPORTANT: SC_GUSTAVO_GONZALEZ must not be any seat's appointed encryption agent
    // when this proposal EXECUTES: only the appointed agent may approve for a seat, and
    // once an agent's address is listed as its own seat, its approvals credit that seat
    // instead — the appointing seat is left without a valid approver until it rotates
    // (recoverable at any time; approvals on in-flight proposals are unaffected, as they
    // are recorded per seat owner). The address holds no appointment today; if one
    // appears before execution, the dryrun simulates the release (simulatePreExecution)
    // and checkPostState asserts the invariant. The rule is permanent: after execution,
    // no seat may appoint a listed seat address as its agent.

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
            data: abi.encodeCall(
                ISignerList.updateSettings,
                (ISignerList.Settings({
                        encryptionRegistry: L1.DAO_ENCRYPTION_REGISTRY,
                        minSignerListLength: NEW_MIN_SIGNER_LIST_LENGTH
                    }))
            )
        });
        actions_[1] = Action({
            to: L1.DAO_SIGNER_LIST, value: 0, data: abi.encodeCall(ISignerList.addSigners, (toAdd))
        });
        actions_[2] = Action({
            to: L1.DAO_SIGNER_LIST,
            value: 0,
            data: abi.encodeCall(ISignerList.removeSigners, (toRemove))
        });
        actions_[3] = Action({
            to: L1.DAO_STANDARD_MULTISIG,
            value: 0,
            data: abi.encodeCall(
                IMultisig.updateMultisigSettings,
                (IMultisig.MultisigSettings({
                        onlyListed: true,
                        minApprovals: NEW_STANDARD_MIN_APPROVALS,
                        destinationProposalDuration: DESTINATION_PROPOSAL_DURATION,
                        signerList: L1.DAO_SIGNER_LIST,
                        proposalExpirationPeriod: PROPOSAL_EXPIRATION_PERIOD
                    }))
            )
        });
        actions_[4] = Action({
            to: L1.DAO_EMERGENCY_MULTISIG,
            value: 0,
            data: abi.encodeCall(
                IEmergencyMultisig.updateMultisigSettings,
                (IEmergencyMultisig.MultisigSettings({
                        onlyListed: true,
                        minApprovals: NEW_EMERGENCY_MIN_APPROVALS,
                        signerList: L1.DAO_SIGNER_LIST,
                        proposalExpirationPeriod: PROPOSAL_EXPIRATION_PERIOD
                    }))
            )
        });
        // Housekeeping: prunes unlisted accounts from the EncryptionRegistry's account
        // enumeration. Their appointerOf/agent mappings persist; harmless, as an unlisted
        // appointer can never resolve for approvals.
        actions_[5] = Action({
            to: L1.DAO_ENCRYPTION_REGISTRY,
            value: 0,
            data: abi.encodeCall(IEncryptionRegistry.removeUnused, ())
        });
    }

    /// @dev Asserts every value the actions restate as "unchanged" is still current, and
    /// pins the exact current membership so a stale address fails fast with a clear
    /// message instead of an opaque action revert.
    function checkBaseline() internal view override {
        ISignerList signerList = ISignerList(L1.DAO_SIGNER_LIST);
        check(signerList.addresslistLength() == 9, "member count changed");
        (address encryptionRegistry, uint16 minSignerListLength) = signerList.settings();
        check(encryptionRegistry == L1.DAO_ENCRYPTION_REGISTRY, "encryptionRegistry changed");
        check(minSignerListLength == 8, "minSignerListLength changed");

        (
            bool stdOnlyListed,
            uint16 stdApprovals,
            uint32 stdDuration,
            address stdSignerList,
            uint32 stdExpiration
        ) = IMultisig(L1.DAO_STANDARD_MULTISIG).multisigSettings();
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
        ) = IEmergencyMultisig(L1.DAO_EMERGENCY_MULTISIG).multisigSettings();
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
            check(signerList.isListed(current[i]), "expected current member not listed");
        }
        check(!signerList.isListed(L1.SC_GUSTAVO_GONZALEZ), "new member already listed");
        check(L1.SC_GUSTAVO_GONZALEZ.code.length == 0, "new member is not an EOA");
    }

    /// @dev Defensive: if SC_GUSTAVO_GONZALEZ has become some seat's appointed encryption
    /// agent by execution time, model the appointer releasing it first (a real rotation
    /// appoints a replacement agent instead of un-appointing). No-op while the address
    /// holds no appointment, as is the case today.
    function simulatePreExecution() internal override {
        IEncryptionRegistry registry = IEncryptionRegistry(L1.DAO_ENCRYPTION_REGISTRY);
        address appointer = registry.appointerOf(L1.SC_GUSTAVO_GONZALEZ);
        if (appointer != address(0)) {
            console2.log(
                "simulating agent rotation: releasing SC_GUSTAVO_GONZALEZ, appointer:", appointer
            );
            // Appointing oneself un-appoints (see EncryptionRegistry.appointAgent).
            vm.prank(appointer);
            registry.appointAgent(appointer);
        }
    }

    function checkPostState() internal view override {
        ISignerList signerList = ISignerList(L1.DAO_SIGNER_LIST);
        check(signerList.addresslistLength() == 5, "expected 5 members");

        address[5] memory listed = [
            L1.SC_TAIKO_LABS, L1.SC_L2BEAT, L1.SC_ARAGON, L1.SC_NETHERMIND, L1.SC_GUSTAVO_GONZALEZ
        ];
        for (uint256 i; i < listed.length; ++i) {
            check(signerList.isListed(listed[i]), "retained/new member not listed");
        }
        address[5] memory removed = [
            L1.SC_CHAINBOUND,
            L1.SC_HALBORN,
            L1.SC_DREW_VAN_DER_WERFF,
            L1.SC_TONI_WAHRSTATTER,
            L1.SC_GATTACA
        ];
        for (uint256 i; i < removed.length; ++i) {
            check(!signerList.isListed(removed[i]), "removed member still listed");
        }

        // Action 6 effect: every account still enumerated by the registry is a listed
        // signer, i.e. the removed members were pruned (their appointerOf/agent mappings
        // persist, as documented in Proposal0020.md).
        IEncryptionRegistry registry = IEncryptionRegistry(L1.DAO_ENCRYPTION_REGISTRY);
        address[] memory registered = registry.getRegisteredAccounts();
        for (uint256 i; i < registered.length; ++i) {
            check(
                signerList.isListed(registered[i]),
                string.concat("unlisted account still registered: ", vm.toString(registered[i]))
            );
        }

        // Once listed, SC_GUSTAVO_GONZALEZ must not be any seat's appointed agent: its
        // approvals would credit its own seat, stranding the appointing seat.
        check(
            registry.appointerOf(L1.SC_GUSTAVO_GONZALEZ) == address(0),
            "SC_GUSTAVO_GONZALEZ is an appointed agent; the appointer must rotate before execution"
        );

        (address encryptionRegistry, uint16 minSignerListLength) = signerList.settings();
        check(encryptionRegistry == L1.DAO_ENCRYPTION_REGISTRY, "encryptionRegistry not preserved");
        check(minSignerListLength == NEW_MIN_SIGNER_LIST_LENGTH, "minSignerListLength not updated");

        (
            bool stdOnlyListed,
            uint16 stdApprovals,
            uint32 stdDuration,
            address stdSignerList,
            uint32 stdExpiration
        ) = IMultisig(L1.DAO_STANDARD_MULTISIG).multisigSettings();
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
        ) = IEmergencyMultisig(L1.DAO_EMERGENCY_MULTISIG).multisigSettings();
        check(emergencyApprovals == NEW_EMERGENCY_MIN_APPROVALS, "emergency threshold not updated");
        check(
            emergencyOnlyListed && emergencySignerList == L1.DAO_SIGNER_LIST
                && emergencyExpiration == PROPOSAL_EXPIRATION_PERIOD,
            "emergency settings not preserved"
        );
    }
}
