// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @title EtnaVectorsTest
/// @notice Checks the storage layout of `testdata/etna_vectors/vectors.json`, which the Etna node
/// proves and decodes, against a deployed Inbox and staking registry.
/// @dev Every named slot and packed field must hold what the contract's getter returns, and a
/// probe written at the field's vector offset and width, with every other bit of the word set,
/// must be exactly what the getter reads back: a getter reading another slot, offset or width
/// cannot pass. Full-word fields are probed with a fresh word.
contract EtnaVectorsTest is EtnaInboxTestBase {
    /// @dev `testdata/etna_vectors/vectors.json`.
    string internal vectors;

    function setUp() public override {
        super.setUp();
        vectors = LibEtnaVectors.load();
    }

    // ---------------------------------------------------------------
    // Inbox
    // ---------------------------------------------------------------

    function test_layout_InboxPackedFieldsAreWhatTheGettersRead() external {
        assertEq(_inboxSlot("status"), STATUS_SLOT);
        assertEq(LibEtnaVectors.uintAt(vectors, ".layout.inbox.status_active"), _status(), "active");
        _assertInboxField("status", "status", _status);
        _assertInboxField("recovery_generation", "recovery_generation", _generation);
        _assertInboxField("last_checkpoint_height", "height", _lastHeight);
        _assertInboxField("activation_packed", "genesis_height", _genesisHeight);
        _assertInboxField("activation_packed", "l1_block", _activationL1Block);
        _assertInboxField("activation_packed", "epoch_len_l2", _epochLenL2);
        _assertInboxField("activation_packed", "epoch_len_l1", _epochLenL1);
        _assertInboxField("genesis_cutoff", "genesis_cutoff", _genesisCutoff);
        _assertInboxField("forced_inclusion_config", "delay", _forcedInclusionDelay);
        _assertInboxField("forced_inclusion_config", "max_anchor_age", _maxAnchorAge);

        _saveForcedInclusions(3);
        _assertInboxField("forced_inclusion_head_tail", "head", _forcedInclusionHead);
        _assertInboxField("forced_inclusion_head_tail", "tail", _forcedInclusionTail);
    }

    function test_layout_InboxWordFieldsAreWhatTheGettersRead() external {
        _assertInboxWord("committee_config_hash", _committeeConfigHash);
        _assertInboxWord("last_checkpoint_hash", _lastHash);
        _assertInboxWord("genesis_block_hash", _genesisBlockHash);
        _assertInboxWord("genesis_state_root", _genesisStateRoot);
        _assertInboxWord("genesis_committee_hash", _genesisCommitteeHash);
    }

    /// @dev The anchor and genesis witness slot lists name the slots the node decodes, in proof
    /// order.
    function test_layout_WitnessSlotListsNameTheInboxSlots() external view {
        string[5] memory anchor = [
            "status",
            "recovery_generation",
            "last_checkpoint_height",
            "last_checkpoint_hash",
            "forced_inclusion_head_tail"
        ];
        uint256[] memory listed = vm.parseJsonUintArray(vectors, ".layout.inbox.anchor_slots");
        assertEq(listed.length, anchor.length, "anchor slot count");
        for (uint256 i; i < anchor.length; ++i) {
            assertEq(listed[i], _inboxSlot(anchor[i]), anchor[i]);
        }
        string[9] memory genesis = [
            "status",
            "recovery_generation",
            "activation_packed",
            "genesis_block_hash",
            "genesis_state_root",
            "genesis_cutoff",
            "genesis_committee_hash",
            "committee_config_hash",
            "forced_inclusion_config"
        ];
        listed = vm.parseJsonUintArray(vectors, ".layout.inbox.genesis_slots");
        assertEq(listed.length, genesis.length, "genesis slot count");
        for (uint256 i; i < genesis.length; ++i) {
            assertEq(listed[i], _inboxSlot(genesis[i]), genesis[i]);
        }
    }

    function test_layout_ForcedInclusionEntriesAtTheVectorSlots() external {
        uint64[] memory fees = _saveForcedInclusions(8);
        string memory packing = ".layout.inbox.packing.forced_inclusion_entry_metadata";
        for (uint256 k; k < 2; ++k) {
            string memory p =
                string.concat(".layout.inbox.forced_inclusion_entry_slots[", vm.toString(k), "].");
            uint256 index = LibEtnaVectors.uintAt(vectors, string.concat(p, "index"));
            bytes32 hashSlot = LibEtnaVectors.bytes32At(vectors, string.concat(p, "slots[0]"));
            bytes32 metadataSlot = LibEtnaVectors.bytes32At(vectors, string.concat(p, "slots[1]"));
            assertEq(
                hashSlot,
                keccak256(abi.encode(index, _inboxSlot("forced_inclusion_queue"))),
                "mapping slot"
            );
            assertEq(uint256(metadataSlot), uint256(hashSlot) + 1, "second word");

            IEtnaInbox.ForcedInclusion memory entry =
                etnaInbox.getForcedInclusions(uint48(index), 1)[0];
            assertEq(vm.load(address(etnaInbox), hashSlot), entry.txHash, "tx hash");
            assertEq(entry.txHash, keccak256(_forcedTx(index)), "the submitted bytes");
            uint256 metadata = uint256(vm.load(address(etnaInbox), metadataSlot));
            assertEq(
                LibEtnaVectors.fieldOf(vectors, packing, "timestamp", metadata), entry.timestamp
            );
            assertEq(LibEtnaVectors.fieldOf(vectors, packing, "l1_block", metadata), entry.l1Block);
            assertEq(
                LibEtnaVectors.fieldOf(vectors, packing, "fee_in_gwei", metadata), entry.feeInGwei
            );
            assertEq(entry.feeInGwei, fees[index], "fee");
            assertEq(entry.l1Block, block.number, "submission block");
        }
    }

    // ---------------------------------------------------------------
    // Staking registry
    // ---------------------------------------------------------------

    /// @dev Three entries over three checkpoints: Alice's (setUp), Bob's and Carol's, with a
    /// heartbeat and an exit so every packed entry field is non-zero somewhere.
    function test_layout_RegistryCheckpointsAndEntriesAtTheVectorSlots() external {
        _populateRegistry();
        assertEq(registry.checkpointCount(), 3, "checkpoints");
        assertEq(registry.entryCount(), 3, "entries");

        string memory p = ".layout.registry.";
        bytes32 base = LibEtnaVectors.bytes32At(vectors, string.concat(p, "base"));
        assertEq(_loadRegistry(base), registry.checkpointCount(), "checkpoints.length");
        assertEq(
            _loadRegistry(
                LibEtnaVectors.bytes32At(vectors, string.concat(p, "entries_length_slot"))
            ),
            registry.entryCount(),
            "entries.length"
        );

        string memory head = string.concat(p, "packing.checkpoint_head");
        for (uint256 k; k < 2; ++k) {
            string memory c = string.concat(p, "checkpoint_slots[", vm.toString(k), "].");
            IEtnaStakingRegistry.Checkpoint memory checkpoint =
                registry.checkpointAt(LibEtnaVectors.uintAt(vectors, string.concat(c, "index")));
            bytes32 headSlot = LibEtnaVectors.bytes32At(vectors, string.concat(c, "slots[0]"));
            bytes32 rootSlot = LibEtnaVectors.bytes32At(vectors, string.concat(c, "slots[1]"));
            uint256 word = _loadRegistry(headSlot);
            assertEq(LibEtnaVectors.fieldOf(vectors, head, "l1_block", word), checkpoint.l1Block);
            assertEq(LibEtnaVectors.fieldOf(vectors, head, "count", word), checkpoint.count);
            assertEq(bytes32(_loadRegistry(rootSlot)), checkpoint.entriesRoot, "entries root");
        }

        string memory packed = string.concat(p, "packing.entry_packed");
        for (uint256 k; k < 3; ++k) {
            string memory e = string.concat(p, "entry_slots[", vm.toString(k), "].");
            IEtnaStakingRegistry.Entry memory entry =
                registry.entryAt(LibEtnaVectors.uintAt(vectors, string.concat(e, "index")));
            assertEq(
                bytes32(
                    _loadRegistry(LibEtnaVectors.bytes32At(vectors, string.concat(e, "slots[0]")))
                ),
                entry.pubkey,
                "pubkey"
            );
            assertEq(
                _loadRegistry(LibEtnaVectors.bytes32At(vectors, string.concat(e, "slots[1]"))),
                entry.effStake,
                "effStake"
            );
            uint256 word =
                _loadRegistry(LibEtnaVectors.bytes32At(vectors, string.concat(e, "slots[2]")));
            assertEq(
                LibEtnaVectors.fieldOf(vectors, packed, "active_from_l1", word), entry.activeFromL1
            );
            assertEq(
                LibEtnaVectors.fieldOf(vectors, packed, "exit_effective_l1", word),
                entry.exitEffectiveL1
            );
            assertEq(
                LibEtnaVectors.fieldOf(vectors, packed, "last_heartbeat_at", word),
                entry.lastHeartbeatAt
            );
            assertEq(
                LibEtnaVectors.fieldOf(vectors, packed, "last_heartbeat_seq", word),
                entry.lastHeartbeatSeq
            );
        }
    }

    function test_layout_RegistryPackedFieldsAreWhatTheGettersRead() external {
        _populateRegistry();
        string memory p = ".layout.registry.";
        string memory head = string.concat(p, "packing.checkpoint_head");
        bytes32 headSlot =
            LibEtnaVectors.bytes32At(vectors, string.concat(p, "checkpoint_slots[1].slots[0]"));
        _assertRegistryField(headSlot, head, "l1_block", _checkpoint1L1Block);
        _assertRegistryField(headSlot, head, "count", _checkpoint1Count);

        string memory packed = string.concat(p, "packing.entry_packed");
        bytes32 entrySlot =
            LibEtnaVectors.bytes32At(vectors, string.concat(p, "entry_slots[1].slots[2]"));
        _assertRegistryField(entrySlot, packed, "active_from_l1", _entry1ActiveFrom);
        _assertRegistryField(entrySlot, packed, "exit_effective_l1", _entry1ExitEffective);
        _assertRegistryField(entrySlot, packed, "last_heartbeat_at", _entry1HeartbeatAt);
        _assertRegistryField(entrySlot, packed, "last_heartbeat_seq", _entry1HeartbeatSeq);
    }

    /// @dev A committee witness proves `checkpoints.length`, both words of checkpoint `i` and,
    /// when it exists, the first word of checkpoint `i + 1`, in that order.
    function test_layout_SnapshotSlotsAreTheLengthAndCheckpointSlots() external {
        _populateRegistry();
        bytes32 base = LibEtnaVectors.bytes32At(vectors, ".layout.registry.base");
        uint256 data = uint256(keccak256(abi.encode(base)));
        for (uint256 k; k < 4; ++k) {
            string memory s =
                string.concat(".layout.registry.snapshot_slots[", vm.toString(k), "].");
            uint256 i = LibEtnaVectors.uintAt(vectors, string.concat(s, "index"));
            bool hasNext = vm.parseJsonBool(vectors, string.concat(s, "has_next"));
            bytes32[] memory slots = vm.parseJsonBytes32Array(vectors, string.concat(s, "slots"));
            assertEq(slots.length, hasNext ? 4 : 3, "slot count");
            assertEq(slots[0], base, "checkpoints.length");
            assertEq(uint256(slots[1]), data + 2 * i, "checkpoint head");
            assertEq(uint256(slots[2]), data + 2 * i + 1, "checkpoint root");
            if (hasNext) assertEq(uint256(slots[3]), data + 2 * (i + 1), "next checkpoint head");

            if (i + 1 < registry.checkpointCount()) {
                // The proven values are the snapshot's length, checkpoint and successor.
                IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(i);
                assertEq(_loadRegistry(slots[0]), registry.checkpointCount());
                assertEq(uint64(_loadRegistry(slots[1])), checkpoint.l1Block);
                assertEq(bytes32(_loadRegistry(slots[2])), checkpoint.entriesRoot);
                if (hasNext) {
                    assertEq(uint64(_loadRegistry(slots[3])), registry.checkpointAt(i + 1).l1Block);
                }
            }
        }
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The vector's plain Inbox slot `_name`.
    function _inboxSlot(string memory _name) internal view returns (uint256) {
        return LibEtnaVectors.uintAt(vectors, string.concat(".layout.inbox.slots.", _name));
    }

    /// @dev Asserts that packed field `_field` of Inbox slot `_slot` is what `_read` returns now,
    /// and after a probe written at the field's vector offset and width, with every other bit
    /// of the word set.
    function _assertInboxField(
        string memory _slot,
        string memory _field,
        function() internal view returns (uint256) _read
    )
        internal
    {
        uint256 slot = _inboxSlot(_slot);
        string memory packing = string.concat(".layout.inbox.packing.", _slot);
        string memory label = string.concat(_slot, ".", _field);
        uint256 word = _loadSlot(slot);
        assertEq(LibEtnaVectors.fieldOf(vectors, packing, _field, word), _read(), label);

        uint256 probe = _probe(packing, _field);
        uint256 probed =
            LibEtnaVectors.withField(vectors, packing, _field, type(uint256).max, probe);
        vm.store(address(etnaInbox), bytes32(slot), bytes32(probed));
        assertEq(_read(), probe, string.concat(label, " probe"));
        vm.store(address(etnaInbox), bytes32(slot), bytes32(word));
    }

    /// @dev Asserts that the full-word Inbox slot `_slot` is what `_read` returns, before and
    /// after a fresh word is written there.
    function _assertInboxWord(
        string memory _slot,
        function() internal view returns (bytes32) _read
    )
        internal
    {
        uint256 slot = _inboxSlot(_slot);
        bytes32 word = bytes32(_loadSlot(slot));
        assertEq(word, _read(), _slot);
        bytes32 probe = keccak256(abi.encode("probe", _slot));
        vm.store(address(etnaInbox), bytes32(slot), probe);
        assertEq(_read(), probe, string.concat(_slot, " probe"));
        vm.store(address(etnaInbox), bytes32(slot), word);
    }

    /// @dev As `_assertInboxField`, for the registry word at `_slot` described at `_packing`.
    function _assertRegistryField(
        bytes32 _slot,
        string memory _packing,
        string memory _field,
        function() internal view returns (uint256) _read
    )
        internal
    {
        string memory label = string.concat(_packing, ".", _field);
        uint256 word = _loadRegistry(_slot);
        assertEq(LibEtnaVectors.fieldOf(vectors, _packing, _field, word), _read(), label);

        uint256 probe = _probe(_packing, _field);
        uint256 probed =
            LibEtnaVectors.withField(vectors, _packing, _field, type(uint256).max, probe);
        vm.store(address(registry), _slot, bytes32(probed));
        assertEq(_read(), probe, string.concat(label, " probe"));
        vm.store(address(registry), _slot, bytes32(word));
    }

    /// @dev A probe value for a field: all ones but the lowest bit, so a getter that reads a
    /// different offset or a narrower or wider field returns something else.
    function _probe(string memory _packing, string memory _field) internal view returns (uint256) {
        uint256 bits = LibEtnaVectors.uintAt(vectors, string.concat(_packing, ".", _field, ".bits"));
        return (1 << bits) - 2;
    }

    function _loadRegistry(bytes32 _slot) internal view returns (uint256) {
        return uint256(vm.load(address(registry), _slot));
    }

    /// @dev Adds Bob's entry and Alice's heartbeat in one block, then Carol's entry and Bob's
    /// exit request in the next: checkpoints 1 and 2 after setUp's checkpoint 0.
    function _populateRegistry() internal {
        address[2] memory stakers = [Bob, Carol];
        for (uint256 i; i < stakers.length; ++i) {
            taikoToken.mint(stakers[i], MIN_STAKE);
            vm.prank(stakers[i]);
            taikoToken.approve(address(registry), MIN_STAKE);
        }
        vm.prank(Bob);
        registry.register(bytes32(uint256(0xb2)), MIN_STAKE);
        vm.prank(Alice);
        registry.heartbeat(0);
        _advanceBlock();
        vm.prank(Carol);
        registry.register(bytes32(uint256(0xc3)), MIN_STAKE);
        vm.prank(Bob);
        registry.requestExit(1);
    }

    /// @dev Alice saves `_count` forced inclusions at the current fee each, the `i`-th carrying
    /// `_forcedTx(i)`.
    function _saveForcedInclusions(uint256 _count) internal returns (uint64[] memory fees_) {
        vm.deal(Alice, 1000 ether);
        fees_ = new uint64[](_count);
        for (uint256 i; i < _count; ++i) {
            fees_[i] = etnaInbox.getCurrentForcedInclusionFee();
            vm.prank(Alice);
            etnaInbox.saveForcedInclusion{ value: uint256(fees_[i]) * 1 gwei }(_forcedTx(i));
        }
    }

    function _forcedTx(uint256 _index) internal pure returns (bytes memory) {
        return abi.encodePacked("forced transaction ", _index);
    }

    // Getters as uniform `uint256`/`bytes32` readers for the field checks.

    function _status() internal view returns (uint256) {
        return etnaInbox.migrationState();
    }

    function _generation() internal view returns (uint256) {
        return etnaInbox.recoveryGeneration();
    }

    function _lastHeight() internal view returns (uint256) {
        return etnaInbox.lastCheckpoint().height;
    }

    function _lastHash() internal view returns (bytes32) {
        return etnaInbox.lastCheckpoint().blockHash;
    }

    function _genesisHeight() internal view returns (uint256) {
        return etnaInbox.activation().genesisHeight;
    }

    function _activationL1Block() internal view returns (uint256) {
        return etnaInbox.activation().l1Block;
    }

    function _epochLenL2() internal view returns (uint256) {
        return etnaInbox.activation().epochLenL2;
    }

    function _epochLenL1() internal view returns (uint256) {
        return etnaInbox.activation().epochLenL1;
    }

    function _genesisBlockHash() internal view returns (bytes32) {
        return etnaInbox.activation().genesisBlockHash;
    }

    function _genesisStateRoot() internal view returns (bytes32) {
        return etnaInbox.activation().genesisStateRoot;
    }

    function _genesisCutoff() internal view returns (uint256) {
        return etnaInbox.genesisCutoff();
    }

    function _committeeConfigHash() internal view returns (bytes32) {
        return etnaInbox.committeeConfigHash();
    }

    function _genesisCommitteeHash() internal view returns (bytes32) {
        return etnaInbox.genesisCommitteeRecordHash();
    }

    function _forcedInclusionDelay() internal view returns (uint256) {
        return etnaInbox.forcedInclusionDelay();
    }

    function _maxAnchorAge() internal view returns (uint256) {
        return etnaInbox.maxAnchorAge();
    }

    function _forcedInclusionHead() internal view returns (uint256) {
        (uint48 head,) = etnaInbox.getForcedInclusionState();
        return head;
    }

    function _forcedInclusionTail() internal view returns (uint256) {
        (, uint48 tail) = etnaInbox.getForcedInclusionState();
        return tail;
    }

    function _checkpoint1L1Block() internal view returns (uint256) {
        return registry.checkpointAt(1).l1Block;
    }

    function _checkpoint1Count() internal view returns (uint256) {
        return registry.checkpointAt(1).count;
    }

    function _entry1ActiveFrom() internal view returns (uint256) {
        return registry.entryAt(1).activeFromL1;
    }

    function _entry1ExitEffective() internal view returns (uint256) {
        return registry.entryAt(1).exitEffectiveL1;
    }

    function _entry1HeartbeatAt() internal view returns (uint256) {
        return registry.entryAt(1).lastHeartbeatAt;
    }

    function _entry1HeartbeatSeq() internal view returns (uint256) {
        return registry.entryAt(1).lastHeartbeatSeq;
    }
}
