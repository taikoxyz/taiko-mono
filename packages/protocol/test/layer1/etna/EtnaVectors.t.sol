// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { Base64 } from "solady/src/utils/Base64.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title EtnaVectorsTest
/// @notice Pins the frozen Etna storage layout (spec appendix B) and encodings (appendix A) to
/// `testdata/etna_vectors/vectors.json`, the file the Etna node and guests read.
/// @dev Layout tests write raw words at the vector's slots with `vm.store` and read them back
/// through the frozen views of the Inbox proxy (upgraded to `EtnaInbox`, not initialized) and of
/// the registry proxy, so a view that reads another slot, offset or width fails. Encoding tests
/// rebuild every preimage with Solidity's `abi.encode` and compare bytes and hashes. Each test
/// loads the file into memory (`j`); it is too large to keep in storage.
contract EtnaVectorsTest is EtnaInboxTestBase {
    /// @dev `K`, the landing grid interval.
    uint256 private constant _K = 6;

    /// @dev The Inbox proxy on the `EtnaInbox` implementation.
    IEtnaInbox internal inbox;

    function setUp() public override {
        super.setUp();
        EssentialContract(inboxProxy).upgradeTo(address(_newInboxImpl(_defaultConfig())));
        inbox = IEtnaInbox(inboxProxy);
    }

    function test_schema_IsVersionFour() external view {
        assertEq(LibEtnaVectors.stringAt(LibEtnaVectors.load(), ".schema_version"), "4");
    }

    // ---------------------------------------------------------------
    // Inbox layout
    // ---------------------------------------------------------------

    function test_layout_InboxWordSlotsAreWhatTheGettersRead() external {
        string memory j = LibEtnaVectors.load();
        assertEq(_inboxSlot(j, "recovery_generation"), RECOVERY_GENERATION_SLOT);
        assertEq(_inboxSlot(j, "committee_config_hash"), COMMITTEE_CONFIG_HASH_SLOT);
        assertEq(_inboxSlot(j, "last_checkpoint_height"), LAST_CHECKPOINT_HEIGHT_SLOT);
        assertEq(_inboxSlot(j, "last_checkpoint_hash"), LAST_CHECKPOINT_HASH_SLOT);
        assertEq(_inboxSlot(j, "genesis_block_hash"), GENESIS_BLOCK_HASH_SLOT);
        assertEq(_inboxSlot(j, "genesis_state_root"), GENESIS_STATE_ROOT_SLOT);
        assertEq(_inboxSlot(j, "genesis_committee_record_hash"), GENESIS_COMMITTEE_RECORD_HASH_SLOT);
        assertEq(_inboxSlot(j, "genesis_cutoff"), GENESIS_CUTOFF_SLOT);
        assertEq(_inboxSlot(j, "active_committee_snapshot"), ACTIVE_COMMITTEE_SNAPSHOT_SLOT);

        // Every probe is written before any view is read, so a view that reads another of these
        // slots returns that slot's probe instead. The 48-bit fields get values that fit them.
        _storeInbox(j, "recovery_generation", bytes32(_probe48("recovery_generation")));
        _storeInbox(j, "committee_config_hash", _probe("committee_config_hash"));
        _storeInbox(j, "last_checkpoint_height", bytes32(_probe48("last_checkpoint_height")));
        _storeInbox(j, "last_checkpoint_hash", _probe("last_checkpoint_hash"));
        _storeInbox(j, "genesis_block_hash", _probe("genesis_block_hash"));
        _storeInbox(j, "genesis_state_root", _probe("genesis_state_root"));
        _storeInbox(j, "genesis_committee_record_hash", _probe("genesis_committee_record_hash"));
        _storeInbox(j, "genesis_cutoff", bytes32(_probe48("genesis_cutoff")));
        _storeInbox(j, "active_committee_snapshot", _probe("active_committee_snapshot"));

        assertEq(inbox.recoveryGeneration(), _probe48("recovery_generation"), "268");
        assertEq(inbox.committeeConfigHash(), _probe("committee_config_hash"), "269");
        assertEq(inbox.lastCheckpoint().height, _probe48("last_checkpoint_height"), "270");
        assertEq(inbox.lastCheckpoint().blockHash, _probe("last_checkpoint_hash"), "271");
        assertEq(inbox.genesis().genesisBlockHash, _probe("genesis_block_hash"), "273");
        assertEq(inbox.genesis().genesisStateRoot, _probe("genesis_state_root"), "274");
        assertEq(inbox.genesisCommitteeRecordHash(), _probe("genesis_committee_record_hash"), "278");
        assertEq(inbox.genesisCutoff(), _probe48("genesis_cutoff"), "279");
        assertEq(
            inbox.activeCommitteeSnapshot(), uint256(_probe("active_committee_snapshot")), "284"
        );
    }

    function test_layout_InboxPackedWordsDecodeAtVectorOffsets() external {
        string memory j = LibEtnaVectors.load();
        assertEq(_inboxSlot(j, "genesis_packed"), GENESIS_PACKED_SLOT);
        assertEq(_inboxSlot(j, "forced_inclusion_head_tail"), FORCED_INCLUSION_HEAD_TAIL_SLOT);
        assertEq(_inboxSlot(j, "forced_inclusion_config"), FORCED_INCLUSION_CONFIG_SLOT);
        // An ordinary item and an all-max item of each kind.
        assertEq(LibEtnaVectors.lengthAt(j, ".packed_words.inbox_272"), 2);
        assertEq(LibEtnaVectors.lengthAt(j, ".packed_words.inbox_281"), 2);
        assertEq(LibEtnaVectors.lengthAt(j, ".packed_words.inbox_282"), 2);
        for (uint256 i; i < 2; ++i) {
            string memory p = _at(".packed_words.inbox_272", i);
            _storeInbox(j, "genesis_packed", _bytes32(j, p, "word"));
            IEtnaInbox.GenesisRecord memory genesis = inbox.genesis();
            assertEq(genesis.genesisHeight, _uint(j, p, "genesis_height"), "genesisHeight");
            assertEq(genesis.l1Block, _uint(j, p, "l1_block"), "L1_0");
            assertEq(genesis.epochLenL2, _uint(j, p, "epoch_len_l2"), "L");

            p = _at(".packed_words.inbox_281", i);
            _storeInbox(j, "forced_inclusion_head_tail", _bytes32(j, p, "word"));
            (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
            assertEq(head, _uint(j, p, "head"), "head");
            assertEq(tail, _uint(j, p, "tail"), "tail");

            p = _at(".packed_words.inbox_282", i);
            _storeInbox(j, "forced_inclusion_config", _bytes32(j, p, "word"));
            assertEq(inbox.forcedInclusionDelay(), _uint(j, p, "forced_inclusion_delay"), "delay");
            assertEq(inbox.maxAnchorAge(), _uint(j, p, "max_anchor_age"), "maxAnchorAge");
        }
    }

    function test_layout_LandingAndOriginMappingsAtVectorSlots() external {
        string memory j = LibEtnaVectors.load();
        assertEq(_inboxSlot(j, "landings"), LANDINGS_SLOT);
        assertEq(_inboxSlot(j, "origins"), ORIGINS_SLOT);

        string memory landings = ".layout.inbox.landing_slots";
        assertEq(LibEtnaVectors.lengthAt(j, landings), 3);
        for (uint256 k; k < 3; ++k) {
            string memory p = _at(landings, k);
            uint256 height = _uint(j, p, "height");
            bytes32 first = _mappingSlots(j, p, height, LANDINGS_SLOT, 3);
            // Word 1 alternates between the ordinary and the all-max packed item.
            string memory w = _at(".packed_words.inbox_285_word1", k % 2);
            vm.store(inboxProxy, first, _bytes32(j, w, "word"));
            vm.store(inboxProxy, _next(first, 1), _probe(string.concat("elHash", p)));
            vm.store(inboxProxy, _next(first, 2), _probe(string.concat("cometHash", p)));

            IEtnaInbox.Landing memory landing = inbox.landings(height);
            assertEq(landing.parentHeight, _uint(j, w, "parent_height"), "parentHeight");
            assertEq(landing.generation, _uint(j, w, "generation"), "generation");
            assertEq(landing.head, _uint(j, w, "head"), "head");
            assertEq(landing.elHash, _probe(string.concat("elHash", p)), "elHash");
            assertEq(landing.cometHash, _probe(string.concat("cometHash", p)), "cometHash");
        }

        string memory origins = ".layout.inbox.origin_slots";
        assertEq(LibEtnaVectors.lengthAt(j, origins), 2);
        assertEq(LibEtnaVectors.lengthAt(j, ".origin_words"), 2);
        for (uint256 k; k < 2; ++k) {
            string memory p = _at(origins, k);
            string memory o = _at(".origin_words", k);
            uint256 generation = _uint(j, p, "generation");
            assertEq(_uint(j, o, "generation"), generation, "origin word generation");
            bytes32 first = _mappingSlots(j, p, generation, ORIGINS_SLOT, 3);
            vm.store(inboxProxy, first, bytes32(_uint(j, o, "start_height")));
            vm.store(inboxProxy, _next(first, 1), bytes32(_uint(j, o, "l1_block_number")));
            vm.store(inboxProxy, _next(first, 2), bytes32(_uint(j, o, "l1_timestamp")));

            IEtnaInbox.Origin memory origin = inbox.origins(generation);
            assertEq(origin.startHeight, _uint(j, o, "start_height"), "startHeight");
            assertEq(origin.l1BlockNumber, _uint(j, o, "l1_block_number"), "l1BlockNumber");
            assertEq(origin.l1Timestamp, _uint(j, o, "l1_timestamp"), "l1Timestamp");

            // The current generation's origin views read the same record.
            _storeInbox(j, "recovery_generation", bytes32(generation));
            assertEq(inbox.generationStartHeight(), origin.startHeight, "generationStartHeight");
            assertEq(inbox.recoverySnapshot(), origin.l1BlockNumber, "recoverySnapshot");
        }
    }

    function test_layout_ForcedInclusionEntriesAtVectorSlots() external {
        string memory j = LibEtnaVectors.load();
        assertEq(_inboxSlot(j, "forced_inclusion_queue"), FORCED_INCLUSION_QUEUE_SLOT);
        string memory entries = ".layout.inbox.forced_inclusion_entry_slots";
        assertEq(LibEtnaVectors.lengthAt(j, entries), 2);
        assertEq(LibEtnaVectors.lengthAt(j, ".packed_words.inbox_280_word2"), 2);
        uint256 tail;
        for (uint256 k; k < 2; ++k) {
            string memory p = _at(entries, k);
            uint256 index = _uint(j, p, "index");
            bytes32 first = _mappingSlots(j, p, index, FORCED_INCLUSION_QUEUE_SLOT, 2);
            string memory w = _at(".packed_words.inbox_280_word2", k);
            vm.store(inboxProxy, first, _probe(string.concat("txHash", p)));
            vm.store(inboxProxy, _next(first, 1), _bytes32(j, w, "word"));

            IEtnaInbox.ForcedInclusion memory entry = inbox.getForcedInclusion(uint48(index));
            assertEq(entry.txHash, _probe(string.concat("txHash", p)), "txHash");
            assertEq(entry.timestamp, _uint(j, w, "timestamp"), "timestamp");
            assertEq(entry.l1Block, _uint(j, w, "l1_block"), "l1Block");
            if (index + 1 > tail) tail = index + 1;
        }

        // The pending-range view reads the same entries once slot 281 covers them (head 0).
        string memory lanes = ".layout.inbox.packing.forced_inclusion_head_tail.";
        _storeInbox(
            j, "forced_inclusion_head_tail", bytes32(tail << _uint(j, lanes, "tail.offset"))
        );
        IEtnaInbox.ForcedInclusion[] memory pending = inbox.getForcedInclusions(0, uint48(tail));
        assertEq(pending.length, tail, "pending count");
        for (uint256 k; k < 2; ++k) {
            string memory p = _at(entries, k);
            assertEq(
                pending[_uint(j, p, "index")].txHash,
                _probe(string.concat("txHash", p)),
                "pending txHash"
            );
        }
    }

    function test_layout_InitializationStatusSlot() external {
        string memory j = LibEtnaVectors.load();
        uint256 slot = _inboxSlot(j, "initialization_status");
        assertEq(slot, INITIALIZATION_STATUS_SLOT);
        uint256 status = _uint(j, ".layout.inbox.", "initialized_status");
        assertEq(status, 3);
        assertEq(status, EtnaInbox(inboxProxy).INITIALIZED_STATUS());

        assertFalse(inbox.isInitialized(), "zero");
        vm.store(inboxProxy, bytes32(slot), bytes32(status - 1));
        assertFalse(inbox.isInitialized(), "status - 1");
        vm.store(inboxProxy, bytes32(slot), bytes32(status));
        assertTrue(inbox.isInitialized(), "status");
    }

    /// @dev The anchor witness proves exactly these slots, in this order (appendix A); a node
    /// decodes them as the generation, the checkpoint and the queue pointers.
    function test_layout_AnchorSlotsAreGenerationCheckpointAndQueue() external {
        string memory j = LibEtnaVectors.load();
        string memory anchor = ".layout.inbox.anchor_slots";
        assertEq(LibEtnaVectors.lengthAt(j, anchor), 4);
        uint256[4] memory slots;
        for (uint256 i; i < 4; ++i) {
            slots[i] = LibEtnaVectors.uintAt(j, string.concat(anchor, "[", vm.toString(i), "]"));
        }
        assertEq(slots[0], 268);
        assertEq(slots[1], 270);
        assertEq(slots[2], 271);
        assertEq(slots[3], 281);
        assertEq(slots[0], _inboxSlot(j, "recovery_generation"));
        assertEq(slots[1], _inboxSlot(j, "last_checkpoint_height"));
        assertEq(slots[2], _inboxSlot(j, "last_checkpoint_hash"));
        assertEq(slots[3], _inboxSlot(j, "forced_inclusion_head_tail"));

        string memory queue = _at(".packed_words.inbox_281", 0);
        vm.store(inboxProxy, bytes32(slots[0]), bytes32(_probe48("anchor generation")));
        vm.store(inboxProxy, bytes32(slots[1]), bytes32(_probe48("anchor height")));
        vm.store(inboxProxy, bytes32(slots[2]), _probe("anchor hash"));
        vm.store(inboxProxy, bytes32(slots[3]), _bytes32(j, queue, "word"));

        assertEq(inbox.recoveryGeneration(), _probe48("anchor generation"), "generation");
        IEtnaInbox.LandedCheckpoint memory checkpoint = inbox.lastCheckpoint();
        assertEq(checkpoint.height, _probe48("anchor height"), "checkpoint height");
        assertEq(checkpoint.blockHash, _probe("anchor hash"), "checkpoint hash");
        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertEq(head, _uint(j, queue, "head"), "head");
        assertEq(tail, _uint(j, queue, "tail"), "tail");
    }

    // ---------------------------------------------------------------
    // Registry layout
    // ---------------------------------------------------------------

    function test_layout_RegistryArraysAndNamespacesAtVectorSlots() external {
        string memory j = LibEtnaVectors.load();
        string memory r = ".layout.registry.";
        assertEq(LibEtnaVectors.stringAt(j, string.concat(r, "namespace")), "taiko.etna.registry");
        bytes32 base = _bytes32(j, r, "base");
        assertEq(base, _erc7201("taiko.etna.registry"), "base");
        assertEq(_bytes32(j, r, "checkpoints_slot"), base, "checkpoints at R");
        assertEq(uint256(_bytes32(j, r, "entries_slot")), uint256(base) + 1, "entries at R + 1");
        assertEq(_uint(j, r, "no_exit"), registry.NO_EXIT(), "no exit");

        // Array lengths at R and R + 1, wide enough for every indexed vector slot.
        vm.store(address(registry), base, bytes32(uint256(6)));
        vm.store(address(registry), _next(base, 1), bytes32(registry.MAX_ENTRIES()));
        assertEq(registry.checkpointCount(), 6, "checkpoints.length");
        assertEq(registry.entryCount(), registry.MAX_ENTRIES(), "entries.length");

        _assertCheckpointSlots(j, base);
        _assertEntrySlots(j, base);
        _assertSnapshotSlots(j, base);
        _assertNamespace(j, "owners", "taiko.etna.registry.owners");
        _assertNamespace(j, "exit_confirmations", "taiko.etna.registry.exit-confirmations");
    }

    // ---------------------------------------------------------------
    // Encodings
    // ---------------------------------------------------------------

    function test_config_SevenWordOpening() external view {
        string memory j = LibEtnaVectors.load();
        string memory p = ".committee_config.inputs.";
        assertEq(LibEtnaVectors.tagAt(j, string.concat(p, "tag")), "ETNA_PARENT_ANCHOR_V1");
        assertEq(_uint(j, p, "l2_chain_id"), L2_CHAIN_ID, "l2ChainId");
        assertEq(_address(j, p, "registry"), _address(j, ".deployment.", "registry"), "registry");
        IEtnaInbox.CommitteeConfig memory config = IEtnaInbox.CommitteeConfig({
            vpUnit: _uint(j, p, "vp_unit"),
            sMin: _uint(j, p, "s_min"),
            nMax: _uint(j, p, "n_max"),
            unsettledLimit: _uint(j, p, "unsettled_limit")
        });
        bytes memory preimage = abi.encode(
            bytes32("ETNA_PARENT_ANCHOR_V1"),
            uint256(L2_CHAIN_ID),
            _address(j, p, "registry"),
            config.vpUnit,
            config.sMin,
            config.nMax,
            config.unsettledLimit
        );
        assertEq(preimage.length, 224);
        assertEq(preimage, _bytes(j, ".committee_config.", "preimage"));
        assertEq(keccak256(preimage), _bytes32(j, ".committee_config.", "hash"));
    }

    function test_committeeSets_EncodeSetKeysLeavesNodesAndRecords() external view {
        string memory j = LibEtnaVectors.load();
        assertEq(LibEtnaVectors.lengthAt(j, ".committee_sets"), 4);
        // Spec 4.3 rejects an empty committee, so case 0 carries no root or record.
        string memory empty = _at(".committee_sets", 0);
        assertEq(LibEtnaVectors.lengthAt(j, string.concat(empty, "members")), 0);
        assertFalse(vm.parseJsonBool(j, string.concat(empty, "valid")));
        assertEq(LibEtnaVectors.stringAt(j, string.concat(empty, "reason")), "empty_committee");
        assertFalse(vm.keyExistsJson(j, string.concat(empty, "set_root")));

        uint256[3] memory sizes = [uint256(1), 3, 5];
        for (uint256 c = 1; c < 4; ++c) {
            _assertCommitteeSet(j, _at(".committee_sets", c), sizes[c - 1]);
        }
    }

    function test_cuts_LeavesAndCutHashes() external view {
        string memory j = LibEtnaVectors.load();
        string memory table = ".cuts.table";
        assertEq(LibEtnaVectors.lengthAt(j, table), 19);
        for (uint256 x; x < 19; ++x) {
            string memory p = _at(table, x);
            assertEq(_uint(j, p, "height"), x);
            assertEq(_bytes32(j, p, "block_hash"), _cutBlockHash(x), "blockHash");
            assertEq(_bytes32(j, p, "comet_hash"), _cutCometHash(x), "cometHash");
            assertEq(_uint(j, p, "forced_head"), x / _K, "forcedHead");
            bytes memory preimage = _cutLeafPreimage(x);
            assertEq(preimage.length, 128);
            assertEq(preimage, _bytes(j, p, "preimage"));
            assertEq(keccak256(preimage), _bytes32(j, p, "leaf"));
        }

        string memory cases = ".cuts.cut_hashes";
        uint256 n = LibEtnaVectors.lengthAt(j, cases);
        assertEq(n, 5);
        bool sawEmpty;
        for (uint256 c; c < n; ++c) {
            sawEmpty = _assertCutHash(j, _at(cases, c)) || sawEmpty;
        }
        assertTrue(sawEmpty, "an empty leaf list");
    }

    function test_statements_TwentyOneWords() external view {
        string memory j = LibEtnaVectors.load();
        assertEq(LibEtnaVectors.lengthAt(j, ".land_statements"), 2);
        assertEq(LibEtnaVectors.stringAt(j, ".land_statements[0].name"), "genesis");
        assertEq(LibEtnaVectors.stringAt(j, ".land_statements[1].name"), "nonzero");
        for (uint256 i; i < 2; ++i) {
            string memory p = _at(".land_statements", i);
            string memory input = string.concat(p, "inputs.");
            bytes32 blobHashesHash =
                keccak256(abi.encodePacked(_bytes32Array(j, input, "blob_hashes")));
            assertEq(blobHashesHash, _bytes32(j, p, "blob_hashes_hash"), "blob hashes hash");
            bytes memory preimage = bytes.concat(
                _statementWords0To6(j, input),
                _statementWords7To13(j, input),
                _statementWords14To20(j, input, blobHashesHash)
            );
            assertEq(preimage.length, 672);
            assertEq(preimage, _bytes(j, p, "preimage"));
            assertEq(keccak256(preimage), _bytes32(j, p, "hash"));
        }
    }

    function test_landAbi_SelectorAndCalldata() external view {
        string memory j = LibEtnaVectors.load();
        string memory a = ".land_abi.";
        string memory signature = LibEtnaVectors.stringAt(j, string.concat(a, "signature"));
        assertEq(
            signature,
            "land((uint256,uint256,bytes32,bytes32,bytes32,uint256,uint256,uint256),bytes32[],bytes)"
        );
        assertEq(_bytes(j, a, "selector").length, 4);
        bytes4 selector = bytes4(_bytes(j, a, "selector"));
        assertEq(IEtnaInbox.land.selector, selector, "IEtnaInbox.land selector");
        assertEq(bytes4(keccak256(bytes(signature))), selector, "signature selector");

        assertEq(LibEtnaVectors.stringAt(j, string.concat(a, "statement")), "nonzero");
        IEtnaInbox.LandInput memory input = _landInput(j, ".land_statements[1].inputs.");
        // The leaves are the cut leaves at the grid points strictly between p and h.
        bytes32[] memory leaves = _bytes32Array(j, a, "leaves");
        assertEq(leaves.length, (input.lastHeight - input.parentHeight) / _K - 1);
        for (uint256 i; i < leaves.length; ++i) {
            assertEq(leaves[i], keccak256(_cutLeafPreimage(input.parentHeight + _K * (i + 1))));
        }
        assertEq(
            abi.encodeCall(IEtnaInbox.land, (input, leaves, _bytes(j, a, "proof"))),
            _bytes(j, a, "calldata")
        );
    }

    function test_chainDomains_DigestAndFortyEightByteChainId() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".chain_domains");
        assertEq(n, 5);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".chain_domains", i);
            uint256 generation = _uint(j, p, "generation");
            assertLe(generation, type(uint48).max);
            bytes memory preimage = abi.encode(
                bytes32("ETNA_COMET_DOMAIN_V1"),
                _uint(j, p, "l1_chain_id"),
                _uint(j, p, "l2_chain_id"),
                _address(j, p, "inbox"),
                uint48(generation)
            );
            assertEq(preimage, _bytes(j, p, "preimage"));
            bytes32 chainDomain = keccak256(preimage);
            assertEq(chainDomain, _bytes32(j, p, "chain_domain"));
            string memory chainId =
                string.concat("etna-", Base64.encode(abi.encodePacked(chainDomain), true, true));
            assertEq(bytes(chainId).length, 48);
            assertEq(chainId, LibEtnaVectors.stringAt(j, string.concat(p, "chain_id")));
        }
    }

    function test_extraData_ThirteenBytes() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".extra_data");
        assertEq(n, 3);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".extra_data", i);
            uint256 generation = _uint(j, p, "generation");
            uint256 anchorNumber = _uint(j, p, "anchor_number");
            assertLe(generation, type(uint48).max);
            assertLe(anchorNumber, type(uint48).max);
            bytes memory extraData =
                abi.encodePacked(uint8(100), uint48(generation), uint48(anchorNumber));
            assertEq(extraData.length, 13);
            assertEq(extraData, _bytes(j, p, "extra_data"));
        }
    }

    /// @dev `entryKey = keccak256(abi.encode(ckPrefix, ckX))` identifies a slot's occupant for
    /// recovery exclusions (appendix A).
    function test_entryKeys() external view {
        string memory j = LibEtnaVectors.load();
        // A released slot's entry is all zero.
        bytes32 releasedKey = keccak256(abi.encode(0, 0));
        assertEq(releasedKey, keccak256(abi.encode(uint256(0), bytes32(0))));
        uint256 n = LibEtnaVectors.lengthAt(j, ".keys");
        assertEq(n, 6);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".keys", i);
            uint256 ckPrefix = _uint(j, p, "ck_prefix");
            bytes32 ckX = _bytes32(j, p, "ck_x");
            assertEq(_bytes(j, p, "public_key"), abi.encodePacked(uint8(ckPrefix), ckX), "33 B");
            bytes32 entryKey = keccak256(abi.encode(ckPrefix, ckX));
            assertEq(entryKey, _bytes32(j, p, "entry_key"));
            assertNotEq(entryKey, releasedKey);
        }
    }

    function test_registerDigest_MatchesRegistryAtVectorAddress() external {
        string memory j = LibEtnaVectors.load();
        uint256 l1ChainId = _uint(j, ".deployment.", "l1_chain_id");
        address at = _address(j, ".deployment.", "registry");
        vm.chainId(l1ChainId);
        vm.etch(at, address(new EtnaStakingRegistry(_registryConfig())).code);
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("EtnaStakingRegistry"),
                keccak256("1"),
                l1ChainId,
                at
            )
        );

        uint256 n = LibEtnaVectors.lengthAt(j, ".register_digests");
        assertEq(n, 2 * LibEtnaVectors.lengthAt(j, ".keys"));
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".register_digests", i);
            assertEq(_uint(j, p, "l1_chain_id"), l1ChainId);
            assertEq(_address(j, p, "registry"), at);
            assertEq(_bytes32(j, p, "domain_separator"), domainSeparator, "domain separator");
            bytes32 digest = IEtnaStakingRegistry(at).registerDigest(_address(j, p, "owner"));
            assertEq(digest, _bytes32(j, p, "digest"), "registerDigest");
            _assertDigestParts(j, p, domainSeparator, digest);
            // The cases run key by key, both owners each; the PoP recovers to the key's address.
            string memory key = _at(".keys", i / 2);
            assertEq(_bytes(j, p, "key"), _bytes(j, key, "public_key"), "key");
            assertEq(_recover(digest, _bytes(j, p, "pop_sig")), _address(j, key, "ck_addr"), "PoP");
        }
    }

    // ---------------------------------------------------------------
    // Helpers: registry layout
    // ---------------------------------------------------------------

    /// @dev Each vector checkpoint (two words at `keccak256(R) + 2i`) reads back through
    /// `checkpointAt`; packed word 1 alternates between the ordinary and the all-max item.
    function _assertCheckpointSlots(string memory _j, bytes32 _base) private {
        string memory checkpoints = ".layout.registry.checkpoint_slots";
        uint256 data = uint256(keccak256(abi.encode(_base)));
        assertEq(LibEtnaVectors.lengthAt(_j, checkpoints), 3);
        for (uint256 k; k < 3; ++k) {
            string memory p = _at(checkpoints, k);
            uint256 index = _uint(_j, p, "index");
            bytes32 first = _bytes32(_j, p, "slots[0]");
            assertEq(uint256(first), data + 2 * index, "checkpoint word 1");
            assertEq(uint256(_bytes32(_j, p, "slots[1]")), uint256(first) + 1, "checkpoint word 2");
            string memory w = _at(".packed_words.registry_checkpoint_word1", k % 2);
            vm.store(address(registry), first, _bytes32(_j, w, "word"));
            vm.store(address(registry), _next(first, 1), _probe(string.concat("root", p)));

            IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(index);
            assertEq(checkpoint.l1Block, _uint(_j, w, "l1_block"), "l1Block");
            assertEq(checkpoint.count, _uint(_j, w, "count"), "count");
            assertEq(checkpoint.entriesRoot, _probe(string.concat("root", p)), "entriesRoot");
        }
    }

    /// @dev Each vector entry (three words at `keccak256(R + 1) + 3j`) reads back through
    /// `entryAt`; packed word 3 alternates between the ordinary and the all-max item.
    function _assertEntrySlots(string memory _j, bytes32 _base) private {
        string memory entries = ".layout.registry.entry_slots";
        uint256 data = uint256(keccak256(abi.encode(_next(_base, 1))));
        assertEq(LibEtnaVectors.lengthAt(_j, entries), 3);
        for (uint256 k; k < 3; ++k) {
            string memory p = _at(entries, k);
            uint256 index = _uint(_j, p, "index");
            bytes32 first = _bytes32(_j, p, "slots[0]");
            assertEq(uint256(first), data + 3 * index, "entry word 1");
            assertEq(uint256(_bytes32(_j, p, "slots[1]")), uint256(first) + 1, "entry word 2");
            assertEq(uint256(_bytes32(_j, p, "slots[2]")), uint256(first) + 2, "entry word 3");
            string memory w = _at(".packed_words.registry_entry_word3", k % 2);
            vm.store(address(registry), first, _probe(string.concat("ckX", p)));
            vm.store(address(registry), _next(first, 1), _probe(string.concat("effStake", p)));
            vm.store(address(registry), _next(first, 2), _bytes32(_j, w, "word"));

            IEtnaStakingRegistry.Entry memory entry = registry.entryAt(index);
            assertEq(entry.ckX, _probe(string.concat("ckX", p)), "ckX");
            assertEq(entry.effStake, uint256(_probe(string.concat("effStake", p))), "effStake");
            assertEq(entry.ckPrefix, _uint(_j, w, "ck_prefix"), "ckPrefix");
            assertEq(entry.activeFromL1, _uint(_j, w, "active_from_l1"), "activeFromL1");
            assertEq(entry.exitEffectiveL1, _uint(_j, w, "exit_effective_l1"), "exitEffectiveL1");
        }
    }

    /// @dev A committee witness proves `checkpoints.length` (R), both words of checkpoint `i`
    /// and, with a successor, the first word of checkpoint `i + 1`, in that order.
    function _assertSnapshotSlots(string memory _j, bytes32 _base) private view {
        string memory snapshots = ".layout.registry.snapshot_slots";
        uint256 data = uint256(keccak256(abi.encode(_base)));
        assertEq(LibEtnaVectors.lengthAt(_j, snapshots), 3);
        for (uint256 k; k < 3; ++k) {
            string memory p = _at(snapshots, k);
            uint256 index = _uint(_j, p, "index");
            bool hasNext = vm.parseJsonBool(_j, string.concat(p, "has_next"));
            bytes32[] memory slots = _bytes32Array(_j, p, "slots");
            assertEq(slots.length, hasNext ? 4 : 3, "slot count");
            assertEq(slots[0], _base, "checkpoints.length");
            assertEq(uint256(slots[1]), data + 2 * index, "checkpoint word 1");
            assertEq(uint256(slots[2]), data + 2 * index + 1, "checkpoint word 2");
            if (hasNext) assertEq(uint256(slots[3]), data + 2 * index + 2, "next word 1");
        }
    }

    /// @dev The namespace's base is its ERC-7201 slot, and a value written at each vector slot
    /// `keccak256(abi.encode(bondId, base))` is what the registry's view returns for that bond id,
    /// so the registry's private base constant is the vector's.
    function _assertNamespace(string memory _j, string memory _key, string memory _ns) private {
        string memory p = string.concat(".layout.registry.", _key, ".");
        assertEq(LibEtnaVectors.stringAt(_j, string.concat(p, "namespace")), _ns);
        bytes32 base = _bytes32(_j, p, "base");
        assertEq(base, _erc7201(_ns), "base");
        string memory slots = string.concat(p, "slots");
        assertEq(LibEtnaVectors.lengthAt(_j, slots), 2);
        bool isOwners = keccak256(bytes(_key)) == keccak256("owners");
        for (uint256 k; k < 2; ++k) {
            string memory s = _at(slots, k);
            uint256 bondId = _uint(_j, s, "bond_id");
            bytes32 slot = _bytes32(_j, s, "slot");
            assertEq(slot, keccak256(abi.encode(bondId, base)), "mapping slot");
            uint256 value = uint256(_probe(string.concat(_key, s)));
            if (isOwners) {
                value = uint160(value);
                vm.store(address(registry), slot, bytes32(value));
                assertEq(registry.ownerOf(bondId), address(uint160(value)), "ownerOf");
            } else {
                vm.store(address(registry), slot, bytes32(value));
                assertEq(registry.exitConfirmedAtL1(bondId), value, "exitConfirmedAtL1");
            }
        }
    }

    // ---------------------------------------------------------------
    // Helpers: encodings
    // ---------------------------------------------------------------

    /// @dev Checks one committee set: ascending set keys, member leaves, odd-node promotion, the
    /// root, the total power and the five-field record (appendix A).
    function _assertCommitteeSet(string memory _j, string memory _p, uint256 _size) private view {
        assertTrue(vm.parseJsonBool(_j, string.concat(_p, "valid")));
        assertEq(_uint(_j, _p, "l2_chain_id"), L2_CHAIN_ID);
        uint256 k = _uint(_j, _p, "set_version");
        assertEq(k, _uint(_j, _p, "target_epoch") + 1, "k = targetEpoch + 1");
        assertEq(LibEtnaVectors.lengthAt(_j, string.concat(_p, "members")), _size);

        bytes32[] memory level = new bytes32[](_size);
        uint256 totalPower;
        for (uint256 i; i < _size; ++i) {
            level[i] = _memberLeaf(_j, _p, i, k);
            totalPower += _uint(_j, _member(_p, i), "power");
        }
        for (uint256 width = _size; width > 1; width = (width + 1) / 2) {
            for (uint256 i; i < width; i += 2) {
                level[i / 2] = i + 1 == width
                    ? level[i]
                    : keccak256(
                        abi.encode(
                            bytes32("ETNA_SET_NODE"),
                            uint256(L2_CHAIN_ID),
                            k,
                            level[i],
                            level[i + 1]
                        )
                    );
            }
        }
        assertEq(level[0], _bytes32(_j, _p, "set_root"), "setRoot");
        assertEq(totalPower, _uint(_j, _p, "total_power"), "totalPower");

        bytes memory record = abi.encode(
            bytes32("ETNA_COMMITTEE_V1"),
            uint256(L2_CHAIN_ID),
            _uint(_j, _p, "target_epoch"),
            _uint(_j, _p, "cutoff_l1_block"),
            _uint(_j, _p, "checkpoint_index"),
            level[0],
            totalPower
        );
        assertEq(record, _bytes(_j, _p, "record_preimage"), "record preimage");
        assertEq(keccak256(record), _bytes32(_j, _p, "record_hash"), "record hash");
    }

    /// @dev Checks member `_i`'s set key, order and power, and returns its leaf.
    function _memberLeaf(
        string memory _j,
        string memory _p,
        uint256 _i,
        uint256 _k
    )
        private
        pure
        returns (bytes32 leaf_)
    {
        string memory m = _member(_p, _i);
        uint256 ckPrefix = _uint(_j, m, "ck_prefix");
        bytes32 ckX = _bytes32(_j, m, "ck_x");
        bytes32 setKey =
            keccak256(abi.encode(bytes32("ETNA_SET_KEY_V1"), uint256(L2_CHAIN_ID), ckPrefix, ckX));
        assertEq(setKey, _bytes32(_j, m, "set_key"), "setKey");
        if (_i != 0) {
            assertGt(uint256(setKey), uint256(_bytes32(_j, _member(_p, _i - 1), "set_key")));
        }
        uint256 vpUnit = _uint(_j, ".committee_config.inputs.", "vp_unit");
        assertEq(_uint(_j, m, "power"), _uint(_j, m, "eff_stake") / vpUnit, "power");

        // The eight leaf words, split in two to stay within the legacy pipeline's stack.
        bytes memory preimage = bytes.concat(
            abi.encode(bytes32("ETNA_SET_LEAF_V1"), uint256(L2_CHAIN_ID), _k, _i),
            abi.encode(ckPrefix, ckX, _uint(_j, m, "eff_stake"), _uint(_j, m, "power"))
        );
        string memory index = string.concat("[", vm.toString(_i), "]");
        assertEq(preimage, _bytes(_j, _p, string.concat("set_leaf_preimages", index)), "preimage");
        leaf_ = keccak256(preimage);
        assertEq(leaf_, _bytes32(_j, _p, string.concat("set_leaves", index)), "leaf");
    }

    /// @dev Checks one cut hash case, rebuilding its leaves from the cut model; returns whether
    /// its leaf list is empty.
    function _assertCutHash(string memory _j, string memory _p) private pure returns (bool empty_) {
        uint256 parentHeight = _uint(_j, _p, "parent_height");
        uint256 lastHeight = _uint(_j, _p, "last_height");
        bytes32[] memory leaves = new bytes32[]((lastHeight - parentHeight) / _K - 1);
        bytes32[] memory listed = _bytes32Array(_j, _p, "leaves");
        assertEq(listed.length, leaves.length, "leaf count");
        for (uint256 i; i < leaves.length; ++i) {
            leaves[i] = keccak256(_cutLeafPreimage(parentHeight + _K * (i + 1)));
            assertEq(leaves[i], listed[i], "leaf");
        }
        bytes32 leavesHash = keccak256(abi.encodePacked(leaves));
        assertEq(leavesHash, _bytes32(_j, _p, "leaves_hash"), "leavesHash");
        empty_ = leaves.length == 0;
        if (empty_) assertEq(leavesHash, keccak256(""), "empty list");
        bytes memory preimage = abi.encode(
            bytes32("ETNA_LAND_CUTS_V1"),
            _uint(_j, _p, "generation"),
            parentHeight,
            lastHeight,
            leavesHash
        );
        assertEq(preimage, _bytes(_j, _p, "preimage"), "cut hash preimage");
        assertEq(keccak256(preimage), _bytes32(_j, _p, "cut_hash"), "cutHash");
    }

    /// @dev The cut model at height `_x`: EL hash 100 + x, Comet hash 200 + x (0 at x = 0) and FI
    /// cursor x / 6; `cutLeaf` is the keccak256 of these four words.
    function _cutLeafPreimage(uint256 _x) private pure returns (bytes memory) {
        return abi.encode(_x, _cutBlockHash(_x), _cutCometHash(_x), _x / _K);
    }

    function _cutBlockHash(uint256 _x) private pure returns (bytes32) {
        return bytes32(100 + _x);
    }

    function _cutCometHash(uint256 _x) private pure returns (bytes32) {
        return _x == 0 ? bytes32(0) : bytes32(200 + _x);
    }

    /// @dev Statement words 0-6: tag, chain ids, Inbox, registry, generation and p.
    function _statementWords0To6(
        string memory _j,
        string memory _in
    )
        private
        pure
        returns (bytes memory)
    {
        assertEq(LibEtnaVectors.tagAt(_j, string.concat(_in, "tag")), "TAIKO_ETNA_LAND_V1");
        return abi.encode(
            bytes32("TAIKO_ETNA_LAND_V1"),
            _uint(_j, _in, "l1_chain_id"),
            _uint(_j, _in, "l2_chain_id"),
            _address(_j, _in, "inbox"),
            _address(_j, _in, "registry"),
            _uint(_j, _in, "generation"),
            _uint(_j, _in, "parent_height")
        );
    }

    /// @dev Statement words 7-13: the origin hashes, the configuration hash and the terminal
    /// height, hashes and state root.
    function _statementWords7To13(
        string memory _j,
        string memory _in
    )
        private
        pure
        returns (bytes memory)
    {
        assertEq(
            _bytes32(_j, _in, "committee_config_hash"),
            _bytes32(_j, ".committee_config.", "hash"),
            "config"
        );
        return abi.encode(
            _bytes32(_j, _in, "parent_hash"),
            _bytes32(_j, _in, "parent_comet_hash"),
            _bytes32(_j, _in, "committee_config_hash"),
            _uint(_j, _in, "last_height"),
            _bytes32(_j, _in, "last_block_hash"),
            _bytes32(_j, _in, "last_comet_hash"),
            _bytes32(_j, _in, "last_state_root")
        );
    }

    /// @dev Statement words 14-20: the reference block, the blob hashes hash, the queue heads,
    /// the active committee snapshot and the cut hash.
    function _statementWords14To20(
        string memory _j,
        string memory _in,
        bytes32 _blobHashesHash
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encode(
            _uint(_j, _in, "l1_reference_block_number"),
            _bytes32(_j, _in, "l1_reference_block_hash"),
            _blobHashesHash,
            _uint(_j, _in, "forced_inclusion_head_before"),
            _uint(_j, _in, "forced_inclusion_head_after"),
            _uint(_j, _in, "active_committee_snapshot"),
            _bytes32(_j, _in, "cut_hash")
        );
    }

    /// @dev The statement inputs at `_in` as `land`'s eight public inputs.
    function _landInput(
        string memory _j,
        string memory _in
    )
        private
        pure
        returns (IEtnaInbox.LandInput memory)
    {
        return IEtnaInbox.LandInput({
            parentHeight: _uint(_j, _in, "parent_height"),
            lastHeight: _uint(_j, _in, "last_height"),
            lastBlockHash: _bytes32(_j, _in, "last_block_hash"),
            lastCometHash: _bytes32(_j, _in, "last_comet_hash"),
            lastStateRoot: _bytes32(_j, _in, "last_state_root"),
            l1ReferenceBlockNumber: _uint(_j, _in, "l1_reference_block_number"),
            forcedInclusionHead: _uint(_j, _in, "forced_inclusion_head_after"),
            activeCommitteeSnapshot: _uint(_j, _in, "active_committee_snapshot")
        });
    }

    /// @dev `digest = keccak256(0x1901 || domainSeparator || structHash)` with the EIP-712
    /// `Register(address owner)` struct hash of the case's owner.
    function _assertDigestParts(
        string memory _j,
        string memory _p,
        bytes32 _domainSeparator,
        bytes32 _digest
    )
        private
        pure
    {
        bytes32 structHash =
            keccak256(abi.encode(keccak256("Register(address owner)"), _address(_j, _p, "owner")));
        assertEq(_bytes32(_j, _p, "struct_hash"), structHash, "struct hash");
        assertEq(
            _digest, keccak256(abi.encodePacked(hex"1901", _domainSeparator, structHash)), "digest"
        );
    }

    /// @dev `ecrecover` of a 65-byte `R || S || V` signature with V in {0, 1}.
    function _recover(bytes32 _digest, bytes memory _sig) private pure returns (address) {
        require(_sig.length == 65, "signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(_sig, 0x20))
            s := mload(add(_sig, 0x40))
            v := byte(0, mload(add(_sig, 0x60)))
        }
        return ecrecover(_digest, v + 27, r, s);
    }

    function _registryConfig() private view returns (IEtnaStakingRegistry.Config memory) {
        return IEtnaStakingRegistry.Config({
            token: address(taikoToken),
            minStake: MIN_STAKE,
            activationDelay: ACTIVATION_DELAY,
            exitDelay: EXIT_DELAY,
            withdrawalDelay: WITHDRAWAL_DELAY,
            slashBountyBps: SLASH_BOUNTY_BPS,
            slashSink: SLASH_SINK,
            l2ChainId: L2_CHAIN_ID,
            inbox: inboxProxy
        });
    }

    // ---------------------------------------------------------------
    // Helpers: vectors and storage
    // ---------------------------------------------------------------

    /// @dev The vector's plain Inbox slot `_name`.
    function _inboxSlot(string memory _j, string memory _name) private pure returns (uint256) {
        return _uint(_j, ".layout.inbox.slots.", _name);
    }

    /// @dev Writes `_word` at the vector's Inbox slot `_name`.
    function _storeInbox(string memory _j, string memory _name, bytes32 _word) private {
        vm.store(inboxProxy, bytes32(_inboxSlot(_j, _name)), _word);
    }

    /// @dev Checks that item `_p`'s `slots` are `_count` consecutive words from the mapping slot
    /// `keccak256(abi.encode(_key, _slot))`, and returns the first.
    function _mappingSlots(
        string memory _j,
        string memory _p,
        uint256 _key,
        uint256 _slot,
        uint256 _count
    )
        private
        pure
        returns (bytes32 first_)
    {
        bytes32[] memory slots = _bytes32Array(_j, _p, "slots");
        assertEq(slots.length, _count, "word count");
        first_ = keccak256(abi.encode(_key, _slot));
        for (uint256 w; w < _count; ++w) {
            assertEq(slots[w], _next(first_, w), "mapping word slot");
        }
    }

    /// @dev `keccak256(abi.encode(uint256(keccak256(_namespace)) - 1)) & ~0xff`.
    function _erc7201(string memory _namespace) private pure returns (bytes32) {
        return
            keccak256(abi.encode(uint256(keccak256(bytes(_namespace))) - 1))
                & ~bytes32(uint256(0xff));
    }

    function _next(bytes32 _slot, uint256 _offset) private pure returns (bytes32) {
        return bytes32(uint256(_slot) + _offset);
    }

    /// @dev A distinct full-word probe for `_label`.
    function _probe(string memory _label) private pure returns (bytes32) {
        return keccak256(abi.encode("probe", _label));
    }

    /// @dev A distinct probe for `_label` that fits a 48-bit field.
    function _probe48(string memory _label) private pure returns (uint256) {
        return uint256(_probe(_label)) & type(uint48).max;
    }

    /// @dev `"<_array>[<_index>]."`, the path prefix of an array item's fields.
    function _at(string memory _array, uint256 _index) private pure returns (string memory) {
        return string.concat(_array, "[", vm.toString(_index), "].");
    }

    function _member(string memory _p, uint256 _i) private pure returns (string memory) {
        return _at(string.concat(_p, "members"), _i);
    }

    function _uint(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (uint256)
    {
        return LibEtnaVectors.uintAt(_j, string.concat(_p, _field));
    }

    function _bytes32(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (bytes32)
    {
        return LibEtnaVectors.bytes32At(_j, string.concat(_p, _field));
    }

    function _address(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (address)
    {
        return LibEtnaVectors.addressAt(_j, string.concat(_p, _field));
    }

    function _bytes(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (bytes memory)
    {
        return LibEtnaVectors.bytesAt(_j, string.concat(_p, _field));
    }

    /// @dev Reads the `bytes32` array at `_p` + `_field` (possibly empty).
    function _bytes32Array(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (bytes32[] memory)
    {
        return vm.parseJsonBytes32Array(_j, string.concat(_p, _field));
    }
}
