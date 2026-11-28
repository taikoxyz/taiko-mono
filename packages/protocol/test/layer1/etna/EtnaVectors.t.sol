// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibEtnaKeys } from "src/shared/etna/LibEtnaKeys.sol";
import { LibEtnaVectorAbi } from "test/shared/etna/LibEtnaVectorAbi.sol";
import { EtnaVectorReader, LibEtnaVectors } from "test/shared/etna/LibEtnaVectors.sol";

/// @title EtnaVectorsTest
/// @notice Pins the Etna Inbox storage layout (spec appendix B) and encodings (appendix A) to
/// `testdata/etna_vectors/vectors.json`, the file the Etna node and guests read.
/// @dev Layout tests write raw words at the vector's slots with `vm.store` and read them back
/// through the views of the Inbox proxy (upgraded to `EtnaInbox`, not initialized), so a view
/// that reads another slot, offset or width fails. Encoding tests rebuild every preimage with
/// Solidity's `abi.encode` and compare bytes and hashes. Each test loads the file into memory
/// (`j`); it is too large to keep in storage.
contract EtnaVectorsTest is EtnaInboxTestBase, EtnaVectorReader {
    struct ValEntry {
        uint8 ckPrefix;
        bytes32 ckX;
        uint64 votingPower;
        int64 proposerPriority;
    }

    /// @dev The cut model's FI cursor advances once every `_FI_STEP` heights.
    uint256 private constant _FI_STEP = 6;

    /// @dev The tag of the config hash (appendix A).
    bytes32 private constant _CONFIG_TAG = bytes32("ETNA_CONFIG_V1");

    /// @dev The X of K2, the compressed key of private key 2.
    bytes32 private constant _K2_X =
        0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5;

    /// @dev The Inbox proxy on the `EtnaInbox` implementation.
    IEtnaInbox internal inbox;

    function setUp() public override {
        super.setUp();
        EssentialContract(inboxProxy).upgradeTo(address(inboxImpl));
        inbox = IEtnaInbox(inboxProxy);
    }

    /// @dev The layout tests plant words into an uninitialized Inbox.
    function _initializeOnSetUp() internal pure override returns (bool) {
        return false;
    }

    /// @dev Schema 11 adds the staking contract's `miss_release_limit` to the deployment and to
    /// the block-start cases; schema 10 moved staking to the L2 `EtnaStaking` contract and gave the
    /// Inbox the DAO fallback key set and `minTotalStake`.
    function test_schema_IsVersionEleven() external view {
        assertEq(LibEtnaVectors.stringAt(LibEtnaVectors.load(), ".schema_version"), "11");
    }

    // ---------------------------------------------------------------
    // Validator state and app hash
    // ---------------------------------------------------------------

    /// @dev The published encoding-only example pins signed priorities and both stored proposers.
    function test_validatorState_PublishedEncoding() external view {
        string memory j = LibEtnaVectors.load();
        string memory p = ".validator_states[0].";
        ValEntry[] memory current = new ValEntry[](2);
        current[0] = ValEntry(2, bytes32(uint256(1)), 10, -5);
        current[1] = ValEntry(3, bytes32(uint256(2)), 10, 5);
        ValEntry[] memory next = new ValEntry[](2);
        next[0] = ValEntry(2, bytes32(uint256(1)), 10, 5);
        next[1] = ValEntry(3, bytes32(uint256(2)), 10, -5);
        bytes memory preimage = abi.encode(
            bytes32("ETNA_VAL_STATE_V1"), uint256(6), current, uint256(1), next, uint256(0)
        );
        assertEq(preimage.length, 768);
        assertEq(preimage, _bytes(j, p, "preimage"));
        assertEq(keccak256(preimage), _bytes32(j, p, "hash"));
        assertEq(
            keccak256(preimage), 0x368f341ba9eb8b6d6cadbd5b944daed7ed417b273d1257911a7fd18320f2a81b
        );
        assertEq(
            keccak256(
                abi.encode(
                    bytes32("ETNA_VAL_STATE_V1"), uint256(6), current, uint256(0), next, uint256(0)
                )
            ),
            _bytes32(j, p, "changed_current_proposer_hash")
        );
        assertEq(
            keccak256(
                abi.encode(
                    bytes32("ETNA_VAL_STATE_V1"), uint256(6), current, uint256(1), next, uint256(1)
                )
            ),
            _bytes32(j, p, "changed_next_proposer_hash")
        );
    }

    /// @dev The published app hash: appHash(6) of EL hash 0x11..11 and the validator-state hash
    /// above, three words; no landing record, cut leaf or statement holds either hash.
    function test_appHash_PublishedThreeWordEncoding() external view {
        string memory j = LibEtnaVectors.load();
        string memory p = ".app_hashes[0].";
        assertEq(LibEtnaVectors.lengthAt(j, ".app_hashes"), 1);
        assertEq(_string(j, p, "name"), "ENC-A-29b.g");
        assertEq(_uint(j, p, "height"), 6);
        bytes32 valStateHash = _bytes32(j, ".validator_states[0].", "hash");
        assertEq(_bytes32(j, p, "val_state_hash"), valStateHash);
        bytes memory preimage =
            abi.encode(bytes32("ETNA_APP_HASH_V1"), _bytes32(j, p, "block_hash"), valStateHash);
        assertEq(preimage.length, 96);
        assertEq(preimage, _bytes(j, p, "preimage"));
        assertEq(keccak256(preimage), _bytes32(j, p, "hash"));
        assertEq(
            keccak256(
                abi.encode(
                    bytes32("ETNA_APP_HASH_V1"),
                    bytes32(0x1111111111111111111111111111111111111111111111111111111111111111),
                    bytes32(0x368f341ba9eb8b6d6cadbd5b944daed7ed417b273d1257911a7fd18320f2a81b)
                )
            ),
            0x381ceb5a317bd34b0b19b9972191a994c384b4873a3694cfd46cb155c7d8b451
        );
    }

    // ---------------------------------------------------------------
    // Inbox layout
    // ---------------------------------------------------------------

    function test_layout_InboxWordSlotsAreWhatTheGettersRead() external {
        string memory j = LibEtnaVectors.load();
        assertEq(_inboxSlot(j, "recovery_generation"), RECOVERY_GENERATION_SLOT);
        assertEq(_inboxSlot(j, "config_hash"), CONFIG_HASH_SLOT);
        assertEq(_inboxSlot(j, "last_checkpoint_height"), LAST_CHECKPOINT_HEIGHT_SLOT);
        assertEq(_inboxSlot(j, "last_checkpoint_hash"), LAST_CHECKPOINT_HASH_SLOT);
        assertEq(_inboxSlot(j, "genesis_block_hash"), GENESIS_BLOCK_HASH_SLOT);
        assertEq(_inboxSlot(j, "genesis_state_root"), GENESIS_STATE_ROOT_SLOT);
        assertEq(_inboxSlot(j, "fallback_keys_hash"), FALLBACK_KEYS_HASH_SLOT);
        assertEq(_inboxSlot(j, "min_total_stake"), MIN_TOTAL_STAKE_SLOT);
        assertEq(_inboxSlot(j, "recovery_nonce"), RECOVERY_NONCE_SLOT);

        // Every probe is written before any view is read, so a view that reads another of these
        // slots returns that slot's probe instead. The 48-bit fields get values that fit them.
        _storeInbox(j, "recovery_generation", bytes32(_probe48("recovery_generation")));
        _storeInbox(j, "config_hash", _probe("config_hash"));
        _storeInbox(j, "last_checkpoint_height", bytes32(_probe48("last_checkpoint_height")));
        _storeInbox(j, "last_checkpoint_hash", _probe("last_checkpoint_hash"));
        _storeInbox(j, "genesis_block_hash", _probe("genesis_block_hash"));
        _storeInbox(j, "genesis_state_root", _probe("genesis_state_root"));
        _storeInbox(j, "fallback_keys_hash", _probe("fallback_keys_hash"));
        _storeInbox(j, "min_total_stake", _probe("min_total_stake"));
        _storeInbox(j, "recovery_nonce", _probe("recovery_nonce"));

        assertEq(inbox.recoveryGeneration(), _probe48("recovery_generation"), "268");
        assertEq(inbox.configHash(), _probe("config_hash"), "269");
        assertEq(inbox.lastCheckpoint().height, _probe48("last_checkpoint_height"), "270");
        assertEq(inbox.lastCheckpoint().blockHash, _probe("last_checkpoint_hash"), "271");
        assertEq(inbox.genesis().startBlockHash, _probe("genesis_block_hash"), "273");
        assertEq(inbox.genesis().startStateRoot, _probe("genesis_state_root"), "274");
        assertEq(inbox.fallbackKeysHash(), _probe("fallback_keys_hash"), "278");
        assertEq(inbox.minTotalStake(), uint256(_probe("min_total_stake")), "279 full uint256");
        assertEq(inbox.recoveryNonce(), uint256(_probe("recovery_nonce")), "292 full uint256");
    }

    function test_layout_InboxPackedWordsDecodeAtVectorOffsets() external {
        string memory j = LibEtnaVectors.load();
        assertEq(_inboxSlot(j, "forced_inclusion_head_tail"), FORCED_INCLUSION_HEAD_TAIL_SLOT);
        assertEq(_inboxSlot(j, "forced_inclusion_config"), FORCED_INCLUSION_CONFIG_SLOT);
        assertEq(_inboxSlot(j, "rules_schedule"), RULES_SCHEDULE_SLOT);
        // An ordinary item and an all-max item of each kind.
        assertEq(LibEtnaVectors.lengthAt(j, ".packed_words.inbox_281"), 2);
        assertEq(LibEtnaVectors.lengthAt(j, ".packed_words.inbox_282"), 2);
        assertEq(LibEtnaVectors.lengthAt(j, ".packed_words.inbox_293"), 2);
        for (uint256 i; i < 2; ++i) {
            string memory p = _at(".packed_words.inbox_281", i);
            _storeInbox(j, "forced_inclusion_head_tail", _bytes32(j, p, "word"));
            (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
            assertEq(head, _uint(j, p, "head"), "head");
            assertEq(tail, _uint(j, p, "tail"), "tail");

            p = _at(".packed_words.inbox_282", i);
            _storeInbox(j, "forced_inclusion_config", _bytes32(j, p, "word"));
            assertEq(inbox.forcedInclusionDelay(), _uint(j, p, "forced_inclusion_delay"), "delay");
            assertEq(inbox.maxAnchorAge(), _uint(j, p, "max_anchor_age"), "maxAnchorAge");

            p = _at(".packed_words.inbox_293", i);
            _storeInbox(j, "rules_schedule", _bytes32(j, p, "word"));
            _assertRulesSchedule(j, p);
        }
    }

    /// @dev Slot 272 packs the Etna start S and L1_0, 48 bits each from the least-significant
    /// bit, with every bit from 96 up zero; `init` on a new network writes (0, block.number).
    function test_layout_Slot272PacksStartAndL1Block() external {
        string memory j = LibEtnaVectors.load();
        assertEq(_inboxSlot(j, "genesis_packed"), GENESIS_PACKED_SLOT);
        string memory lanes = ".layout.inbox.packing.genesis_packed.";
        assertEq(_uint(j, lanes, "genesis_height.offset"), 0, "S offset");
        assertEq(_uint(j, lanes, "genesis_height.bits"), 48, "S width");
        assertEq(_uint(j, lanes, "l1_block.offset"), 48, "L1_0 offset");
        assertEq(_uint(j, lanes, "l1_block.bits"), 48, "L1_0 width");
        assertEq(LibEtnaVectors.lengthAt(j, ".packed_words.inbox_272"), 2);
        for (uint256 i; i < 2; ++i) {
            string memory p = _at(".packed_words.inbox_272", i);
            uint256 word = uint256(_bytes32(j, p, "word"));
            uint256 start = _uint(j, p, "genesis_height");
            uint256 l1Block = _uint(j, p, "l1_block");
            assertEq(word >> 96, 0, "bits from 96 up");
            assertEq(word, start | (l1Block << 48), "packing");
            _storeInbox(j, "genesis_packed", bytes32(word));
            IEtnaInbox.GenesisRecord memory record = inbox.genesis();
            assertEq(record.genesisHeight, start, "genesisHeight");
            assertEq(record.l1Block, l1Block, "L1_0");
            (uint48 height,) = inbox.etnaStart();
            assertEq(height, start, "etnaStart height");
        }

        _storeInbox(j, "genesis_packed", bytes32(0));
        vm.roll(_uint(j, _at(".packed_words.inbox_272", 0), "l1_block"));
        inbox.init(_defaultInitParams());
        assertEq(
            vm.load(inboxProxy, bytes32(GENESIS_PACKED_SLOT)),
            bytes32(block.number << 48),
            "the start write: S = 0 and L1_0 = block.number"
        );
    }

    function test_layout_LandingMappingAtVectorSlots() external {
        string memory j = LibEtnaVectors.load();
        assertEq(_inboxSlot(j, "landings"), LANDINGS_SLOT);
        string memory lanes = ".layout.inbox.packing.landing_word1.";
        assertEq(_uint(j, lanes, "parent_height.offset"), 0);
        assertEq(_uint(j, lanes, "generation.offset"), 48);
        assertEq(_uint(j, lanes, "head.offset"), 96);

        string memory landings = ".layout.inbox.landing_slots";
        assertEq(LibEtnaVectors.lengthAt(j, landings), 3);
        for (uint256 k; k < 3; ++k) {
            string memory p = _at(landings, k);
            uint256 height = _uint(j, p, "height");
            bytes32 first = _mappingSlots(j, p, height, LANDINGS_SLOT, 3);
            // Word 1 alternates between the ordinary and the all-max packed item.
            string memory w = _at(".packed_words.inbox_285_word1", k % 2);
            assertEq(
                uint256(_bytes32(j, w, "word")),
                _uint(j, w, "parent_height") | (_uint(j, w, "generation") << 48)
                    | (_uint(j, w, "head") << 96),
                "word 1 packing"
            );
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
    }

    /// @dev An origin record is four full words at keccak256(abi.encode(generation, 290)): the
    /// start height, the L1 block number and timestamp, and the fallback key hash that slot 278
    /// held when the record was written.
    function test_layout_OriginMappingHasFourWords() external {
        string memory j = LibEtnaVectors.load();
        assertEq(_inboxSlot(j, "origins"), ORIGINS_SLOT);
        string memory origins = ".layout.inbox.origin_slots";
        assertEq(LibEtnaVectors.lengthAt(j, origins), 2);
        assertEq(LibEtnaVectors.lengthAt(j, ".origin_words"), 2);
        // The start is written whenever an origin record exists, which the start-height view
        // requires.
        _storeInbox(j, "genesis_block_hash", bytes32(uint256(100)));
        for (uint256 k; k < 2; ++k) {
            string memory p = _at(origins, k);
            string memory o = _at(".origin_words", k);
            uint256 generation = _uint(j, p, "generation");
            assertEq(_uint(j, o, "generation"), generation, "origin word generation");
            bytes32 first = _mappingSlots(j, p, generation, ORIGINS_SLOT, 4);
            vm.store(inboxProxy, first, bytes32(_uint(j, o, "start_height")));
            vm.store(inboxProxy, _next(first, 1), bytes32(_uint(j, o, "l1_block_number")));
            vm.store(inboxProxy, _next(first, 2), bytes32(_uint(j, o, "l1_timestamp")));
            vm.store(inboxProxy, _next(first, 3), _bytes32(j, o, "fallback_keys_hash"));

            IEtnaInbox.Origin memory origin = inbox.origins(generation);
            assertEq(origin.startHeight, _uint(j, o, "start_height"), "startHeight");
            assertEq(origin.l1BlockNumber, _uint(j, o, "l1_block_number"), "l1BlockNumber");
            assertEq(origin.l1Timestamp, _uint(j, o, "l1_timestamp"), "l1Timestamp");
            assertEq(origin.fallbackKeysHash, _bytes32(j, o, "fallback_keys_hash"), "keys hash");

            _storeInbox(j, "recovery_generation", bytes32(generation));
            assertEq(inbox.generationStartHeight(), origin.startHeight, "generationStartHeight");
        }
        // The fourth words are the hashes of the lists [K1] and [K1, K2].
        assertEq(
            _bytes32(j, ".origin_words[0].", "fallback_keys_hash"),
            _bytes32(j, ".fallback_keys.accepted[0].", "hash"),
            "[K1]"
        );
        assertEq(
            _bytes32(j, ".origin_words[1].", "fallback_keys_hash"),
            _bytes32(j, ".fallback_keys.accepted[1].", "hash"),
            "[K1, K2]"
        );
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

    /// @dev Slots 283, 284, 286-289 and 291 are reserved: they stay zero through `init`, a
    /// landing and a recovery, which between them write every other word the vectors name.
    function test_layout_ReservedSlotsStayZero() external {
        string memory j = LibEtnaVectors.load();
        string memory list = ".layout.inbox.reserved_slots";
        uint256[7] memory expected = [uint256(283), 284, 286, 287, 288, 289, 291];
        assertEq(LibEtnaVectors.lengthAt(j, list), expected.length, "reserved slot count");
        uint256[] memory reserved = new uint256[](expected.length);
        for (uint256 i; i < expected.length; ++i) {
            reserved[i] = LibEtnaVectors.uintAt(j, string.concat(list, "[", vm.toString(i), "]"));
            assertEq(reserved[i], expected[i], "reserved slot");
        }
        _assertZero(reserved, "before init");

        inbox.init(_defaultInitParams());
        _assertZero(reserved, "after init");

        vm.roll(block.number + 2);
        vm.setBlockhash(block.number - 1, keccak256("reference"));
        bytes32[] memory blobs = new bytes32[](1);
        blobs[0] = keccak256("blob");
        vm.blobhashes(blobs);
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            parentHeight: 0,
            lastHeight: 1,
            lastBlockHash: keccak256("el 1"),
            lastCometHash: keccak256("comet 1"),
            lastStateRoot: keccak256("state 1"),
            l1ReferenceBlockNumber: block.number - 1,
            forcedInclusionHead: 0
        });
        inbox.land(input, new bytes32[](0), "proof");
        assertEq(inbox.lastCheckpoint().height, 1, "landed");
        _assertZero(reserved, "after land");

        inbox.recover(0, 1, 0, block.timestamp, new uint256[](0), 0);
        assertEq(inbox.recoveryGeneration(), 1, "recovered");
        _assertZero(reserved, "after recover");
    }

    /// @dev The anchor witness proves exactly these slots, in this order: the generation, the
    /// checkpoint, the fallback key hash, `minTotalStake`, the queue pointers and the rules
    /// schedule.
    function test_layout_AnchorSlotsInWitnessOrder() external {
        string memory j = LibEtnaVectors.load();
        string memory anchor = ".layout.inbox.anchor_slots";
        uint256[7] memory expected = [uint256(268), 270, 271, 278, 279, 281, 293];
        string[7] memory names = [
            "recovery_generation",
            "last_checkpoint_height",
            "last_checkpoint_hash",
            "fallback_keys_hash",
            "min_total_stake",
            "forced_inclusion_head_tail",
            "rules_schedule"
        ];
        assertEq(LibEtnaVectors.lengthAt(j, anchor), expected.length, "anchor slot count");
        uint256[7] memory slots;
        for (uint256 i; i < expected.length; ++i) {
            slots[i] = LibEtnaVectors.uintAt(j, string.concat(anchor, "[", vm.toString(i), "]"));
            assertEq(slots[i], expected[i], "anchor slot");
            assertEq(slots[i], _inboxSlot(j, names[i]), names[i]);
        }

        string memory queue = _at(".packed_words.inbox_281", 0);
        string memory rules = _at(".packed_words.inbox_293", 0);
        vm.store(inboxProxy, bytes32(slots[0]), bytes32(_probe48("anchor generation")));
        vm.store(inboxProxy, bytes32(slots[1]), bytes32(_probe48("anchor height")));
        vm.store(inboxProxy, bytes32(slots[2]), _probe("anchor hash"));
        vm.store(inboxProxy, bytes32(slots[3]), _probe("anchor keys hash"));
        vm.store(inboxProxy, bytes32(slots[4]), _probe("anchor min total stake"));
        vm.store(inboxProxy, bytes32(slots[5]), _bytes32(j, queue, "word"));
        vm.store(inboxProxy, bytes32(slots[6]), _bytes32(j, rules, "word"));

        assertEq(inbox.recoveryGeneration(), _probe48("anchor generation"), "generation");
        IEtnaInbox.LandedCheckpoint memory checkpoint = inbox.lastCheckpoint();
        assertEq(checkpoint.height, _probe48("anchor height"), "checkpoint height");
        assertEq(checkpoint.blockHash, _probe("anchor hash"), "checkpoint hash");
        assertEq(inbox.fallbackKeysHash(), _probe("anchor keys hash"), "fallback key hash");
        assertEq(inbox.minTotalStake(), uint256(_probe("anchor min total stake")), "minTotalStake");
        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertEq(head, _uint(j, queue, "head"), "head");
        assertEq(tail, _uint(j, queue, "tail"), "tail");
        _assertRulesSchedule(j, rules);
    }

    /// @dev `etnaStart()` returns slots 272 (height) and 273 (hash) as `view_abi` encodes them:
    /// (0, 0) before the start write, and the planted start after it.
    function test_etnaStart_ReturnsTheVectorEncodingOfSlots272And273() external {
        string memory j = LibEtnaVectors.load();
        string memory v = ".view_abi.etna_start.";
        assertEq(_bytes(j, v, "selector"), abi.encodePacked(IEtnaInbox.etnaStart.selector));
        assertEq(_bytes(j, v, "calldata"), abi.encodeCall(IEtnaInbox.etnaStart, ()));
        assertEq(LibEtnaVectors.stringAt(j, string.concat(v, "returns")), "(uint48,bytes32)");

        LibEtnaVectorAbi.assertViewResult(j, "etna_start", "inbox", "not_written", inboxProxy);

        string memory written = string.concat(v, "results[0].");
        assertEq(_string(j, written, "name"), "written");
        _storeInbox(j, "genesis_packed", bytes32(_uint(j, written, "values[0]")));
        _storeInbox(j, "genesis_block_hash", _bytes32(j, written, "values[1]"));
        LibEtnaVectorAbi.assertViewResult(j, "etna_start", "inbox", "written", inboxProxy);
    }

    // ---------------------------------------------------------------
    // Config hash
    // ---------------------------------------------------------------

    function test_config_FourWordOpening() external view {
        string memory j = LibEtnaVectors.load();
        string memory p = ".config.inputs.";
        assertEq(LibEtnaVectors.tagAt(j, string.concat(p, "tag")), _CONFIG_TAG);
        assertEq(_uint(j, p, "l2_chain_id"), L2_CHAIN_ID, "l2ChainId");
        assertEq(_address(j, p, "staking"), _address(j, ".deployment.", "staking"), "staking");
        assertEq(_address(j, p, "staking"), ETNA_STAKING, "the genesis staking proxy");
        uint256 unsettledLimit = _uint(j, p, "unsettled_limit");
        assertEq(unsettledLimit, _uint(j, ".deployment.", "unsettled_limit"), "U");
        assertEq(unsettledLimit, UNSETTLED_LIMIT, "the target deployment's U");
        bytes memory preimage = abi.encode(
            _CONFIG_TAG, uint256(L2_CHAIN_ID), _address(j, p, "staking"), unsettledLimit
        );
        assertEq(preimage.length, 128);
        assertEq(preimage, _bytes(j, ".config.", "preimage"));
        assertEq(keccak256(preimage), _bytes32(j, ".config.", "hash"));
    }

    /// @dev `init` with the default configuration, whose L2 chain id, staking proxy and U are the
    /// vector deployment's, stores the vector `config.hash` in slot 269, and the three views of
    /// the config hash's inputs return `view_abi`'s data. With the initial list [K1] and
    /// minTotalStake 2^256 - 1, it emits `FallbackKeysUpdated`, `MinTotalStakeUpdated` and
    /// `EtnaInitialized` in that order, each as `governance_events` encodes it.
    function test_init_StoresTheVectorConfigHash() external {
        string memory j = LibEtnaVectors.load();
        string memory p = ".config.inputs.";
        assertEq(inbox.l2ChainId(), _uint(j, p, "l2_chain_id"), "l2ChainId");
        assertEq(inbox.etnaStaking(), _address(j, p, "staking"), "staking");
        assertEq(inbox.unsettledLimit(), _uint(j, p, "unsettled_limit"), "U");

        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.minTotalStake = type(uint256).max;
        vm.recordLogs();
        inbox.init(params);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 expected = _bytes32(j, ".config.", "hash");
        assertEq(vm.load(inboxProxy, bytes32(CONFIG_HASH_SLOT)), expected, "slot 269");
        assertEq(inbox.configHash(), expected, "configHash");

        string[3] memory names = ["config_hash", "etna_staking", "unsettled_limit"];
        for (uint256 i; i < names.length; ++i) {
            LibEtnaVectorAbi.assertViewResult(j, names[i], "inbox", "deployment", inboxProxy);
        }

        string[3] memory events =
            ["fallback_keys_updated", "min_total_stake_updated", "etna_initialized"];
        uint256 next;
        for (uint256 i; i < logs.length && next < events.length; ++i) {
            if (logs[i].emitter != inboxProxy) continue;
            string memory e = string.concat(".governance_events.", events[next], ".");
            if (logs[i].topics[0] != _bytes32(j, e, "topic0")) continue;
            LibEtnaVectorAbi.assertEvent(j, events[next], "inbox", logs[i]);
            ++next;
        }
        assertEq(next, events.length, "the three events, in order");
    }

    // ---------------------------------------------------------------
    // Cuts, statements and landing
    // ---------------------------------------------------------------

    function test_cuts_LeavesAndCutHashes() external view {
        string memory j = LibEtnaVectors.load();
        string memory table = ".cuts.table";
        assertEq(LibEtnaVectors.lengthAt(j, table), 19);
        for (uint256 x; x < 19; ++x) {
            string memory p = _at(table, x);
            assertEq(_uint(j, p, "height"), x);
            assertEq(_bytes32(j, p, "block_hash"), _cutBlockHash(x), "blockHash");
            assertEq(_bytes32(j, p, "comet_hash"), _cutCometHash(x), "cometHash");
            assertEq(_uint(j, p, "forced_head"), x / _FI_STEP, "forcedHead");
            bytes memory preimage = _cutLeafPreimage(x);
            assertEq(preimage.length, 128);
            assertEq(preimage, _bytes(j, p, "preimage"));
            assertEq(keccak256(preimage), _bytes32(j, p, "leaf"));
        }

        string memory cases = ".cuts.cut_hashes";
        uint256 n = LibEtnaVectors.lengthAt(j, cases);
        assertEq(n, 7);
        bool sawEmpty;
        for (uint256 c; c < n; ++c) {
            sawEmpty = _assertCutHash(j, _at(cases, c)) || sawEmpty;
        }
        assertTrue(sawEmpty, "an empty leaf list");
    }

    function test_statements_NineteenWords() external view {
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
                _statementWords0To5(j, input),
                _statementWords6To12(j, input),
                _statementWords13To18(j, input, blobHashesHash)
            );
            assertEq(preimage.length, 608);
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
            "land((uint256,uint256,bytes32,bytes32,bytes32,uint256,uint256),bytes32[],bytes)"
        );
        assertEq(_bytes(j, a, "selector").length, 4);
        bytes4 selector = bytes4(_bytes(j, a, "selector"));
        assertEq(IEtnaInbox.land.selector, selector, "IEtnaInbox.land selector");
        assertEq(bytes4(keccak256(bytes(signature))), selector, "signature selector");

        assertEq(LibEtnaVectors.stringAt(j, string.concat(a, "statement")), "nonzero");
        IEtnaInbox.LandInput memory input = _landInput(j, ".land_statements[1].inputs.");
        // The leaves are the cut leaves of every height strictly between p and h.
        bytes32[] memory leaves = _bytes32Array(j, a, "leaves");
        assertEq(leaves.length, input.lastHeight - input.parentHeight - 1);
        for (uint256 i; i < leaves.length; ++i) {
            assertEq(leaves[i], keccak256(_cutLeafPreimage(input.parentHeight + 1 + i)));
        }
        assertEq(
            abi.encodeCall(IEtnaInbox.land, (input, leaves, _bytes(j, a, "proof"))),
            _bytes(j, a, "calldata")
        );
    }

    /// @dev `land` itself hashes the genesis statement vector: an Inbox at the vector address,
    /// planted through the vector slots with landings(0) = (0, 0, 0, bytes32(100), 0), generation
    /// 0 from height 0, head 0 and tail 3, lands (0, 18] with the leaves at 1 to 17.
    function test_land_HashesTheGenesisStatementVector() external {
        string memory j = LibEtnaVectors.load();
        string memory s = ".land_statements[0].";
        string memory input = string.concat(s, "inputs.");
        assertEq(LibEtnaVectors.stringAt(j, string.concat(s, "name")), "genesis");
        address at = _etchVectorInbox(j, input);

        bytes32 parentHash = _bytes32(j, input, "parent_hash");
        assertEq(parentHash, bytes32(uint256(100)), "genesis hash");
        _plantVectorLanding(
            j, at, 0, _uint(j, input, "forced_inclusion_head_before"), parentHash, bytes32(0)
        );
        _plantVectorOrigin(j, at, 0, 0);
        vm.store(at, bytes32(_inboxSlot(j, "last_checkpoint_hash")), parentHash);
        vm.store(
            at,
            bytes32(_inboxSlot(j, "forced_inclusion_head_tail")),
            bytes32(_uint(j, input, "forced_inclusion_head_before") | (uint256(3) << 48))
        );

        bytes32[] memory leaves = _tableLeaves(j, 0, 18);
        string memory cuts = _at(".cuts.cut_hashes", 3);
        assertEq(LibEtnaVectors.stringAt(j, string.concat(cuts, "name")), "g0_p0_h18");
        assertEq(_bytes32(j, cuts, "cut_hash"), _bytes32(j, input, "cut_hash"), "cut hash");
        assertEq(keccak256(abi.encodePacked(leaves)), _bytes32(j, cuts, "leaves_hash"), "leaves");

        IEtnaInbox.LandInput memory landInput = _landInput(j, input);
        bytes memory proof = _bytes(j, ".land_abi.", "proof");
        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, _bytes32(j, s, "hash"), proof)),
            1
        );
        vm.expectEmit(at);
        emit IEtnaInbox.Landed(0, 0, 18, _bytes32(j, input, "cut_hash"), 1);
        IEtnaInbox(at).land(landInput, leaves, proof);

        _assertVectorLanding(j, at, input, 0);
    }

    /// @dev `land` hashes the nonzero statement vector from its exact ABI calldata: generation 1
    /// starts at 6, whose generation-0 record (0, 0, 1, bytes32(106), bytes32(206)) is also the
    /// checkpoint; head 1 and tail 3.
    function test_land_HashesTheNonzeroStatementVector() external {
        string memory j = LibEtnaVectors.load();
        string memory s = ".land_statements[1].";
        string memory input = string.concat(s, "inputs.");
        assertEq(LibEtnaVectors.stringAt(j, string.concat(s, "name")), "nonzero");
        assertEq(LibEtnaVectors.stringAt(j, ".land_abi.statement"), "nonzero");
        address at = _etchVectorInbox(j, input);

        uint256 generation = _uint(j, input, "generation");
        uint256 p = _uint(j, input, "parent_height");
        bytes32 parentHash = _bytes32(j, input, "parent_hash");
        assertEq(generation, 1, "generation");
        assertEq(p, 6, "origin");
        vm.store(at, bytes32(_inboxSlot(j, "recovery_generation")), bytes32(generation));
        // The start (slot 273) is written whenever an origin exists: the cut model's EL hash of
        // height 0, 100 + 0.
        vm.store(at, bytes32(_inboxSlot(j, "genesis_block_hash")), bytes32(uint256(100)));
        _plantVectorOrigin(j, at, 1, p);
        _plantVectorLanding(
            j,
            at,
            1,
            _uint(j, input, "forced_inclusion_head_before"),
            parentHash,
            _bytes32(j, input, "parent_comet_hash")
        );
        vm.store(at, bytes32(_inboxSlot(j, "last_checkpoint_height")), bytes32(p));
        vm.store(at, bytes32(_inboxSlot(j, "last_checkpoint_hash")), parentHash);
        vm.store(
            at,
            bytes32(_inboxSlot(j, "forced_inclusion_head_tail")),
            bytes32(_uint(j, input, "forced_inclusion_head_before") | (uint256(3) << 48))
        );
        assertEq(IEtnaInbox(at).generationStartHeight(), p, "origin is the start height");
        assertEq(IEtnaInbox(at).landings(p).generation, 0, "an older generation's record");

        vm.expectCall(
            address(landVerifier),
            abi.encodeCall(
                IProofVerifier.verifyProof,
                (0, _bytes32(j, s, "hash"), _bytes(j, ".land_abi.", "proof"))
            ),
            1
        );
        vm.expectEmit(at);
        emit IEtnaInbox.Landed(p, p, 18, _bytes32(j, input, "cut_hash"), 1);
        (bool ok, bytes memory reason) = at.call(_bytes(j, ".land_abi.", "calldata"));
        assertTrue(ok, string(reason));

        _assertVectorLanding(j, at, input, p);
    }

    /// @dev The genesis statement vector's (0, 18] transaction lands with the checkpoint above its
    /// origin, so `land` checks the leaf at c against c's record on `.cuts.table` data: c = 6 is
    /// planted through the vector's height-6 landing slots from `.cuts.table[6]`, and c = 12 is
    /// written by landing (6, 12] with `.cuts.table[12]`. From both the verifier receives the
    /// vector statement hash, which binds p and not c, and the record at 18 has parent c; the
    /// list with the leaves at 6 and 12 swapped fails the leaf check at either c.
    function test_land_ChecksTheCutTableLeafAboveTheOrigin() external {
        string memory j = LibEtnaVectors.load();
        string memory input = ".land_statements[0].inputs.";
        address at = _etchVectorInbox(j, input);
        string memory row6 = _at(".cuts.table", 6);
        string memory row12 = _at(".cuts.table", 12);

        _plantVectorLanding(j, at, 0, 0, _bytes32(j, input, "parent_hash"), bytes32(0));
        _plantVectorOrigin(j, at, 0, 0);
        assertEq(_uint(j, _at(".layout.inbox.landing_slots", 1), "height"), 6, "height-6 slots");
        _plantVectorLanding(
            j,
            at,
            1,
            _uint(j, row6, "forced_head"),
            _bytes32(j, row6, "block_hash"),
            _bytes32(j, row6, "comet_hash")
        );
        vm.store(at, bytes32(_inboxSlot(j, "last_checkpoint_height")), bytes32(uint256(6)));
        vm.store(
            at, bytes32(_inboxSlot(j, "last_checkpoint_hash")), _bytes32(j, row6, "block_hash")
        );
        vm.store(
            at,
            bytes32(_inboxSlot(j, "forced_inclusion_head_tail")),
            bytes32(_uint(j, row6, "forced_head") | (uint256(3) << 48))
        );

        bytes32[] memory leaves = _tableLeaves(j, 0, 18);
        assertEq(leaves[5], _bytes32(j, row6, "leaf"), "leaf index c - p - 1 = 5");
        assertEq(leaves[11], _bytes32(j, row12, "leaf"), "leaf index c - p - 1 = 11");
        bytes32[] memory swapped = _tableLeaves(j, 0, 18);
        (swapped[5], swapped[11]) = (leaves[11], leaves[5]);
        uint256 atSix = vm.snapshotState();

        _expectVectorFrontierLeafMismatch(j, at, swapped);
        _landGenesisVectorFrom(j, at, leaves, 6);

        vm.revertToState(atSix);
        IEtnaInbox.LandInput memory toTwelve = _landInput(j, input);
        (toTwelve.parentHeight, toTwelve.lastHeight) = (6, 12);
        toTwelve.lastBlockHash = _bytes32(j, row12, "block_hash");
        toTwelve.lastCometHash = _bytes32(j, row12, "comet_hash");
        toTwelve.lastStateRoot = keccak256("state root 12");
        toTwelve.forcedInclusionHead = _uint(j, row12, "forced_head");
        vm.blobhashes(_bytes32Array(j, input, "blob_hashes"));
        IEtnaInbox(at).land(toTwelve, _tableLeaves(j, 6, 12), _bytes(j, ".land_abi.", "proof"));
        IEtnaInbox.Landing memory twelve = IEtnaInbox(at).landings(12);
        assertEq(twelve.parentHeight, 6, "record at 12 settled on 6");
        assertEq(
            keccak256(
                abi.encode(uint256(12), twelve.elHash, twelve.cometHash, uint256(twelve.head))
            ),
            _bytes32(j, row12, "leaf"),
            "the record at 12 is the table's cut at 12"
        );

        _expectVectorFrontierLeafMismatch(j, at, swapped);
        _landGenesisVectorFrom(j, at, leaves, 12);
    }

    // ---------------------------------------------------------------
    // extraData
    // ---------------------------------------------------------------

    /// @dev Every `extra_data` row is the 29 bytes 0x64 ‖ uint48(generation) ‖ uint48(anchor
    /// number) ‖ uint128(missBitmap), big-endian.
    function test_extraData_TwentyNineBytes() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".extra_data");
        assertEq(n, 5);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".extra_data", i);
            uint256 generation = _uint(j, p, "generation");
            uint256 anchorNumber = _uint(j, p, "anchor_number");
            uint256 missBitmap = _uint(j, p, "miss_bitmap");
            assertLe(generation, type(uint48).max);
            assertLe(anchorNumber, type(uint48).max);
            assertLe(missBitmap, type(uint128).max);
            bytes memory extraData = abi.encodePacked(
                uint8(0x64), uint48(generation), uint48(anchorNumber), uint128(missBitmap)
            );
            assertEq(extraData.length, 29);
            assertEq(extraData, _bytes(j, p, "extra_data"));
        }
    }

    // ---------------------------------------------------------------
    // Fallback keys
    // ---------------------------------------------------------------

    /// @dev Every accepted list hashes to its vector over the 3 + 2n word preimage, and
    /// `setFallbackKeys` with it stores the hash and the list and emits `FallbackKeysUpdated`
    /// with the vector's topics and data. Each key signs as the secp256k1eth address of its
    /// decompressed point, at power 1. For the two_keys list, `getFallbackKeys()` and
    /// `fallbackKeysHash()` return `view_abi`'s data.
    function test_fallbackKeys_AcceptedListsHashAndEmitTheVectorEvent() external {
        string memory j = LibEtnaVectors.load();
        assertEq(
            LibEtnaVectors.tagAt(j, ".fallback_keys.tag"), FALLBACK_KEYS_TAG, "fallback key tag"
        );
        inbox.init(_defaultInitParams());
        string memory list = ".fallback_keys.accepted";
        uint256 n = LibEtnaVectors.lengthAt(j, list);
        assertEq(n, 4, "accepted lists");
        bool sawViewList;
        for (uint256 i; i < n; ++i) {
            uint256 mark = _freeMemory();
            string memory p = _at(list, i);
            string memory name = _string(j, p, "name");
            IEtnaInbox.FallbackKey[] memory keys = _vectorKeys(j, string.concat(p, "keys"));
            bytes memory preimage = abi.encode(FALLBACK_KEYS_TAG, keys);
            assertEq(preimage.length, 32 * (3 + 2 * keys.length), name);
            assertEq(preimage, _bytes(j, p, "preimage"), name);
            bytes32 hash = keccak256(preimage);
            assertEq(hash, _bytes32(j, p, "hash"), name);
            _assertSigners(j, p, keys, name);

            assertEq(_bytes32(j, p, "event.topic0"), IEtnaInbox.FallbackKeysUpdated.selector, name);
            vm.recordLogs();
            inbox.setFallbackKeys(keys);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            assertEq(logs.length, 1, name);
            assertEq(logs[0].emitter, inboxProxy, name);
            assertEq(logs[0].topics.length, 2, name);
            assertEq(logs[0].topics[0], _bytes32(j, p, "event.topic0"), name);
            assertEq(logs[0].topics[1], _bytes32(j, p, "event.topic1"), name);
            assertEq(logs[0].topics[1], hash, name);
            assertEq(logs[0].data, _bytes(j, p, "event.data"), name);

            assertEq(inbox.fallbackKeysHash(), hash, name);
            assertEq(vm.load(inboxProxy, bytes32(FALLBACK_KEYS_HASH_SLOT)), hash, name);
            assertEq(abi.encode(inbox.getFallbackKeys()), abi.encode(keys), name);

            if (keccak256(bytes(name)) == keccak256("two_keys")) {
                sawViewList = true;
                LibEtnaVectorAbi.assertViewResult(j, "get_fallback_keys", "inbox", name, inboxProxy);
                LibEtnaVectorAbi.assertViewResult(
                    j, "fallback_keys_hash", "inbox", name, inboxProxy
                );
            }
            _releaseMemory(mark);
        }
        assertTrue(sawViewList, "the view_abi list is accepted");
    }

    /// @dev Every rejected list reverts, in `init` on an uninitialized Inbox and in
    /// `setFallbackKeys` afterwards: a count outside 1 to 128 or keys not strictly ascending by
    /// `ckPrefix ‖ ckX` with `InvalidFallbackKeys`, an invalid key with the key library's
    /// `InvalidPublicKey`.
    function test_fallbackKeys_RejectedListsRevertForTheirReason() external {
        string memory j = LibEtnaVectors.load();
        string memory list = ".fallback_keys.rejected";
        uint256 n = LibEtnaVectors.lengthAt(j, list);
        assertEq(n, 8, "rejected lists");
        bytes4[] memory errors = new bytes4[](n);
        IEtnaInbox.FallbackKey[][] memory lists = new IEtnaInbox.FallbackKey[][](n);
        uint256[3] memory counts;
        for (uint256 i; i < n; ++i) {
            string memory p = _at(list, i);
            lists[i] = _vectorKeys(j, string.concat(p, "keys"));
            bytes32 reason = keccak256(bytes(_string(j, p, "reason")));
            if (reason == keccak256("count")) {
                errors[i] = IEtnaInbox.InvalidFallbackKeys.selector;
                ++counts[0];
            } else if (reason == keccak256("order")) {
                errors[i] = IEtnaInbox.InvalidFallbackKeys.selector;
                ++counts[1];
            } else if (reason == keccak256("key")) {
                errors[i] = LibEtnaKeys.InvalidPublicKey.selector;
                ++counts[2];
            } else {
                revert(string.concat("unknown reason ", _string(j, p, "reason")));
            }
            IEtnaInbox.InitParams memory params = _defaultInitParams();
            params.fallbackKeys = lists[i];
            vm.expectRevert(errors[i]);
            inbox.init(params);
        }
        assertEq(counts[0], 2, "count");
        assertEq(counts[1], 3, "order");
        assertEq(counts[2], 3, "key");

        inbox.init(_defaultInitParams());
        for (uint256 i; i < n; ++i) {
            vm.expectRevert(errors[i]);
            inbox.setFallbackKeys(lists[i]);
        }
        assertEq(inbox.fallbackKeysHash(), DEFAULT_FALLBACK_KEYS_HASH, "the list is unchanged");
    }

    // ---------------------------------------------------------------
    // Appendix A literals
    // ---------------------------------------------------------------

    /// @dev The appendix A literals of the encodings the contracts share: extraData, the
    /// missBitmap bit order, the block-start calldata, the config hash and the fallback key hash,
    /// each rebuilt with Solidity, compared with the literal copied from the spec and with the
    /// vector file; the dynamic-string twins hash differently.
    function test_appendixA_LiteralsReproduce() external view {
        string memory j = LibEtnaVectors.load();
        string memory a = ".appendix_a_examples.";

        bytes memory zero = abi.encodePacked(uint8(0x64), uint48(0), uint48(0), uint128(0));
        assertEq(zero, abi.encodePacked(uint8(0x64), new bytes(28)), "extraData literal, zeros");
        assertEq(zero, _bytes(j, string.concat(a, "enc_a_10_f."), "extra_data"), "file, zeros");
        bytes memory one =
            abi.encodePacked(uint8(0x64), uint48(1), uint48(258), uint128(2 ** 127 + 1));
        assertEq(
            one,
            hex"64" hex"000000000001" hex"000000000102" hex"80000000000000000000000000000001",
            "extraData literal, generation 1"
        );
        assertEq(one, _bytes(j, string.concat(a, "enc_a_10_h."), "extra_data"), "file, gen 1");

        // Seat s is bit s of missBitmap: seat 0 is the low bit of byte 28, seat 127 the high bit
        // of byte 13.
        bytes memory seats02 = _bytes(j, string.concat(a, "enc_a_10c_a."), "extra_data");
        assertEq(seats02, abi.encodePacked(uint8(0x64), uint48(5), uint48(7), uint128(5)));
        assertEq(uint8(seats02[28]), 0x05, "byte 28 of missBitmap 5");
        _assertSeatBits(j, string.concat(a, "enc_a_10c_a."), 5);
        bytes memory seat127 = _bytes(j, string.concat(a, "enc_a_10c_b."), "extra_data");
        assertEq(seat127, abi.encodePacked(uint8(0x64), uint48(5), uint48(7), uint128(2 ** 127)));
        assertEq(uint8(seat127[13]), 0x80, "byte 13 of missBitmap 2^127");
        _assertSeatBits(j, string.concat(a, "enc_a_10c_b."), 2 ** 127);

        bytes4 selector = bytes4(keccak256("onBlockStart(uint48,uint128)"));
        assertEq(selector, bytes4(0xea987592), "block-start selector literal");
        assertEq(
            abi.encodePacked(selector),
            _bytes(j, string.concat(a, "enc_a_10d_b."), "selector"),
            "file selector"
        );
        bytes memory calldata_ =
            abi.encodeWithSignature("onBlockStart(uint48,uint128)", uint48(1), uint128(5));
        assertEq(calldata_.length, 68, "block-start calldata length");
        assertEq(calldata_, abi.encodePacked(selector, uint256(1), uint256(5)), "two words");
        assertEq(calldata_, _bytes(j, string.concat(a, "enc_a_10d_a."), "calldata"), "file call");

        _assertConfigLiterals(j, string.concat(a, "enc_a_36_a."), string.concat(a, "enc_a_36_f."));
        _assertFallbackKeyLiterals(j, a);
    }

    /// @dev A protocol hash whose domain tag is encoded as a dynamic string is a different hash for
    /// every tag, so no contract accepts it in place of the static word.
    function test_appendixA_DynamicTagRejectsDiffer() external view {
        string memory j = LibEtnaVectors.load();
        string memory list = ".appendix_a_examples.dynamic_tag_rejects";
        uint256 n = LibEtnaVectors.lengthAt(j, list);
        assertGt(n, 0, "rejects");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(list, i);
            bytes memory preimage = _bytes(j, p, "preimage");
            bytes32 hash = keccak256(preimage);
            assertEq(hash, _bytes32(j, p, "hash"), "reject hash");
            assertNotEq(hash, _bytes32(j, p, "accepted_hash"), "differs from the accepted hash");
        }
    }

    // ---------------------------------------------------------------
    // Helpers: layout
    // ---------------------------------------------------------------

    /// @dev `rulesSchedule()` decodes the slot 293 word planted from the packed-word item `_p`.
    function _assertRulesSchedule(string memory _j, string memory _p) private view {
        // Four 48-bit fields leave every bit from 192 up zero.
        assertEq(uint256(_bytes32(_j, _p, "word")) >> 192, 0, "slot 293 high bits");
        IEtnaInbox.RulesSchedule memory rules = inbox.rulesSchedule();
        assertEq(rules.activeRules, _uint(_j, _p, "active_rules"), "activeRules");
        assertEq(rules.nextRules, _uint(_j, _p, "next_rules"), "nextRules");
        assertEq(rules.rulesTime, _uint(_j, _p, "rules_time"), "rulesTime");
        assertEq(rules.stopTime, _uint(_j, _p, "stop_time"), "stopTime");
    }

    /// @dev Every slot of `_slots` holds zero on the Inbox proxy.
    function _assertZero(uint256[] memory _slots, string memory _label) private view {
        for (uint256 i; i < _slots.length; ++i) {
            assertEq(
                vm.load(inboxProxy, bytes32(_slots[i])),
                bytes32(0),
                string.concat(_label, ": slot ", vm.toString(_slots[i]))
            );
        }
    }

    // ---------------------------------------------------------------
    // Helpers: encodings
    // ---------------------------------------------------------------

    /// @dev The config hash of L2 chain id 167000, staking `0x1111…11` and U = 151,200: its
    /// 128-byte preimage and the spec literal, and its 192-byte dynamic-string twin.
    function _assertConfigLiterals(
        string memory _j,
        string memory _accepted,
        string memory _rejected
    )
        private
        pure
    {
        address staking = 0x1111111111111111111111111111111111111111;
        assertEq(_address(_j, _accepted, "inputs.staking"), staking, "config staking");
        assertEq(_uint(_j, _accepted, "inputs.l2_chain_id"), 167_000, "config l2ChainId");
        assertEq(_uint(_j, _accepted, "inputs.unsettled_limit"), 151_200, "config U");
        bytes memory preimage = abi.encode(_CONFIG_TAG, uint256(167_000), staking, uint256(151_200));
        assertEq(preimage.length, 128, "config preimage");
        assertEq(preimage.length, _uint(_j, _accepted, "preimage_bytes"), "config preimage file");
        assertEq(preimage, _bytes(_j, _accepted, "preimage"), "config preimage bytes");
        assertEq(
            keccak256(preimage),
            0x78f4b267763e0c4b58a0606e29530287b1761bf4155630c82e79d3e1215fe3b6,
            "config literal"
        );
        assertEq(keccak256(preimage), _bytes32(_j, _accepted, "hash"), "config file");

        bytes memory dynamicTag =
            abi.encode("ETNA_CONFIG_V1", uint256(167_000), staking, uint256(151_200));
        assertEq(dynamicTag.length, 192, "dynamic config preimage");
        assertEq(dynamicTag, _bytes(_j, _rejected, "preimage"), "dynamic config file");
        assertEq(
            keccak256(dynamicTag),
            0x4a305a25878a5ab6f2d7bd36fcdd3d7a5549d0b55471d812df821723caa6383c,
            "dynamic config literal"
        );
        assertEq(keccak256(dynamicTag), _bytes32(_j, _rejected, "hash"), "dynamic config hash");
    }

    /// @dev The fallback key hashes of [K1] and [K1, K2] with their spec literals and preimage
    /// sizes, and the dynamic-string twin of the first.
    function _assertFallbackKeyLiterals(string memory _j, string memory _a) private view {
        IEtnaInbox.FallbackKey[] memory one = _defaultFallbackKeys();
        IEtnaInbox.FallbackKey[] memory two = new IEtnaInbox.FallbackKey[](2);
        two[0] = one[0];
        two[1] = IEtnaInbox.FallbackKey({ ckPrefix: 2, ckX: _K2_X });

        string memory p = string.concat(_a, "enc_a_36a_a.");
        bytes memory preimage = abi.encode(FALLBACK_KEYS_TAG, one);
        assertEq(preimage.length, 160, "[K1] preimage");
        assertEq(preimage, _bytes(_j, p, "preimage"), "[K1] preimage file");
        assertEq(abi.encode(_vectorKeys(_j, string.concat(p, "keys"))), abi.encode(one), "[K1]");
        assertEq(keccak256(preimage), DEFAULT_FALLBACK_KEYS_HASH, "[K1] literal");
        assertEq(keccak256(preimage), _bytes32(_j, p, "hash"), "[K1] file");

        p = string.concat(_a, "enc_a_36a_b.");
        preimage = abi.encode(FALLBACK_KEYS_TAG, two);
        assertEq(preimage.length, 224, "[K1, K2] preimage");
        assertEq(preimage, _bytes(_j, p, "preimage"), "[K1, K2] preimage file");
        assertEq(abi.encode(_vectorKeys(_j, string.concat(p, "keys"))), abi.encode(two), "[K1, K2]");
        assertEq(
            keccak256(preimage),
            0x2bc20cdc8e87ed785fc8f8012165afba944fd223ecf8973e165e41f4cddf0cea,
            "[K1, K2] literal"
        );
        assertEq(keccak256(preimage), _bytes32(_j, p, "hash"), "[K1, K2] file");

        p = string.concat(_a, "enc_a_36a_g.");
        bytes memory dynamicTag = abi.encode("ETNA_FALLBACK_KEYS_V1", one);
        assertEq(dynamicTag.length, 224, "dynamic [K1] preimage");
        assertEq(dynamicTag, _bytes(_j, p, "preimage"), "dynamic [K1] file");
        assertEq(keccak256(dynamicTag), _bytes32(_j, p, "hash"), "dynamic [K1] hash");
        assertNotEq(keccak256(dynamicTag), DEFAULT_FALLBACK_KEYS_HASH, "differs from [K1]");
    }

    /// @dev The example at `_p` has missBitmap `_bitmap`, and its `seats` are exactly the set bits
    /// of `_bitmap`, bit s for seat s.
    function _assertSeatBits(
        string memory _j,
        string memory _p,
        uint256 _bitmap
    )
        private
        view
    {
        assertEq(_uint(_j, _p, "miss_bitmap"), _bitmap, "missBitmap");
        string memory seats = string.concat(_p, "seats");
        uint256 n = LibEtnaVectors.lengthAt(_j, seats);
        uint256 rebuilt;
        for (uint256 i; i < n; ++i) {
            uint256 seat = LibEtnaVectors.uintAt(_j, string.concat(seats, "[", vm.toString(i), "]"));
            rebuilt |= 2 ** seat;
        }
        assertEq(rebuilt, _bitmap, "the listed seats are the set bits");
    }

    /// @dev Each key of the accepted list at `_p` signs as the secp256k1eth address of its
    /// decompressed point, at power 1, in list order.
    function _assertSigners(
        string memory _j,
        string memory _p,
        IEtnaInbox.FallbackKey[] memory _keyList,
        string memory _name
    )
        private
        view
    {
        string memory validators = string.concat(_p, "validators");
        assertEq(LibEtnaVectors.lengthAt(_j, validators), _keyList.length, _name);
        for (uint256 k; k < _keyList.length; ++k) {
            string memory v = _at(validators, k);
            bytes32 y = LibEtnaKeys.decompress(_keyList[k].ckPrefix, _keyList[k].ckX);
            assertEq(_address(_j, v, "ck_addr"), LibEtnaKeys.ckAddr(_keyList[k].ckX, y), _name);
            assertEq(_uint(_j, v, "power"), 1, _name);
        }
    }

    /// @dev Checks one cut hash case, rebuilding its leaves from the cut model; returns whether
    /// its leaf list is empty.
    function _assertCutHash(
        string memory _j,
        string memory _p
    )
        private
        pure
        returns (bool empty_)
    {
        uint256 parentHeight = _uint(_j, _p, "parent_height");
        uint256 lastHeight = _uint(_j, _p, "last_height");
        bytes32[] memory leaves = new bytes32[](lastHeight - parentHeight - 1);
        bytes32[] memory listed = _bytes32Array(_j, _p, "leaves");
        assertEq(listed.length, leaves.length, "leaf count");
        for (uint256 i; i < leaves.length; ++i) {
            leaves[i] = keccak256(_cutLeafPreimage(parentHeight + 1 + i));
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
        return abi.encode(_x, _cutBlockHash(_x), _cutCometHash(_x), _x / _FI_STEP);
    }

    /// @dev The `.cuts.table` leaves of the heights strictly between `_p` and `_h`.
    function _tableLeaves(
        string memory _j,
        uint256 _p,
        uint256 _h
    )
        private
        pure
        returns (bytes32[] memory leaves_)
    {
        leaves_ = new bytes32[](_h - _p - 1);
        for (uint256 i; i < leaves_.length; ++i) {
            string memory row = _at(".cuts.table", _p + 1 + i);
            assertEq(_uint(_j, row, "height"), _p + 1 + i, "table height");
            leaves_[i] = _bytes32(_j, row, "leaf");
        }
    }

    function _cutBlockHash(uint256 _x) private pure returns (bytes32) {
        return bytes32(100 + _x);
    }

    function _cutCometHash(uint256 _x) private pure returns (bytes32) {
        return _x == 0 ? bytes32(0) : bytes32(200 + _x);
    }

    /// @dev Statement words 0-5: tag, chain ids, Inbox, generation and p.
    function _statementWords0To5(
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
            _uint(_j, _in, "generation"),
            _uint(_j, _in, "parent_height")
        );
    }

    /// @dev Statement words 6-12: the origin hashes, the config hash and the terminal height,
    /// hashes and state root.
    function _statementWords6To12(
        string memory _j,
        string memory _in
    )
        private
        pure
        returns (bytes memory)
    {
        assertEq(_bytes32(_j, _in, "config_hash"), _bytes32(_j, ".config.", "hash"), "config");
        return abi.encode(
            _bytes32(_j, _in, "parent_hash"),
            _bytes32(_j, _in, "parent_comet_hash"),
            _bytes32(_j, _in, "config_hash"),
            _uint(_j, _in, "last_height"),
            _bytes32(_j, _in, "last_block_hash"),
            _bytes32(_j, _in, "last_comet_hash"),
            _bytes32(_j, _in, "last_state_root")
        );
    }

    /// @dev Statement words 13-18: the reference block, the blob hashes hash, the queue heads and
    /// the cut hash.
    function _statementWords13To18(
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
            _bytes32(_j, _in, "cut_hash")
        );
    }

    /// @dev The statement inputs at `_in` as `land`'s seven public inputs.
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
            forcedInclusionHead: _uint(_j, _in, "forced_inclusion_head_after")
        });
    }

    /// @dev The fallback key list at `_list`, an array of `{ck_prefix, ck_x}` items.
    function _vectorKeys(
        string memory _j,
        string memory _list
    )
        private
        view
        returns (IEtnaInbox.FallbackKey[] memory keys_)
    {
        keys_ = new IEtnaInbox.FallbackKey[](LibEtnaVectors.lengthAt(_j, _list));
        for (uint256 k; k < keys_.length; ++k) {
            string memory p = _at(_list, k);
            keys_[k] = IEtnaInbox.FallbackKey({
                ckPrefix: uint8(_uint(_j, p, "ck_prefix")), ckX: _bytes32(_j, p, "ck_x")
            });
        }
    }

    // ---------------------------------------------------------------
    // Helpers: vectors and storage
    // ---------------------------------------------------------------

    /// @dev Etches `EtnaInbox` code at the vector Inbox address with the statement's L2 chain id,
    /// the vector staking proxy and U, this suite's verifier and a fresh SignalService accepting
    /// that address; switches to the statement's L1 chain id, rolls to the block after its
    /// reference block, whose hash it sets, attaches its blobs and plants slot 258 = 3 and the
    /// vector config hash.
    function _etchVectorInbox(
        string memory _j,
        string memory _in
    )
        private
        returns (address at_)
    {
        at_ = _address(_j, ".deployment.", "inbox");
        assertEq(_address(_j, _in, "inbox"), at_, "statement inbox");
        vm.chainId(_uint(_j, _in, "l1_chain_id"));
        signalService = _deploySignalService(at_);
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.etnaStaking = _address(_j, ".deployment.", "staking");
        cfg.l2ChainId = uint64(_uint(_j, _in, "l2_chain_id"));
        cfg.unsettledLimit = uint64(_uint(_j, ".deployment.", "unsettled_limit"));
        vm.etch(at_, address(_newInboxImpl(cfg)).code);

        uint256 ref = _uint(_j, _in, "l1_reference_block_number");
        assertEq(ref, 19_000_000, "reference block");
        vm.roll(ref + 1);
        vm.setBlockhash(ref, _bytes32(_j, _in, "l1_reference_block_hash"));
        vm.blobhashes(_bytes32Array(_j, _in, "blob_hashes"));

        vm.store(
            at_,
            bytes32(_inboxSlot(_j, "initialization_status")),
            bytes32(_uint(_j, ".layout.inbox.", "initialized_status"))
        );
        bytes32 configHash = _bytes32(_j, _in, "config_hash");
        assertEq(configHash, _bytes32(_j, ".config.", "hash"), "config hash");
        vm.store(at_, bytes32(_inboxSlot(_j, "config_hash")), configHash);
    }

    /// @dev Writes the record (0, 0, `_head`, `_el`, `_comet`) at the vector's landing slots item
    /// `_index`.
    function _plantVectorLanding(
        string memory _j,
        address _target,
        uint256 _index,
        uint256 _head,
        bytes32 _el,
        bytes32 _comet
    )
        private
    {
        bytes32[] memory slots =
            _bytes32Array(_j, _at(".layout.inbox.landing_slots", _index), "slots");
        vm.store(_target, slots[0], bytes32(_head << 96));
        vm.store(_target, slots[1], _el);
        vm.store(_target, slots[2], _comet);
    }

    /// @dev Writes origin (`_startHeight`, 18,990,000, 1,700,000,000, the hash of [K1]) for
    /// `_generation` at the vector's four origin slots.
    function _plantVectorOrigin(
        string memory _j,
        address _target,
        uint256 _generation,
        uint256 _startHeight
    )
        private
    {
        string memory p = _at(".layout.inbox.origin_slots", _generation);
        assertEq(_uint(_j, p, "generation"), _generation, "origin generation");
        bytes32[] memory slots = _bytes32Array(_j, p, "slots");
        assertEq(slots.length, 4, "four origin words");
        vm.store(_target, slots[0], bytes32(_startHeight));
        vm.store(_target, slots[1], bytes32(uint256(18_990_000)));
        vm.store(_target, slots[2], bytes32(uint256(1_700_000_000)));
        vm.store(_target, slots[3], DEFAULT_FALLBACK_KEYS_HASH);
    }

    /// @dev Checks the writes of a vector landing ending at 18 that settled on `_c`: the record
    /// at the vector's height-18 slots, the checkpoint, the queue head and the SignalService
    /// checkpoint.
    function _assertVectorLanding(
        string memory _j,
        address _target,
        string memory _in,
        uint256 _c
    )
        private
        view
    {
        string memory p = _at(".layout.inbox.landing_slots", 2);
        assertEq(_uint(_j, p, "height"), 18, "landing height");
        bytes32[] memory slots = _bytes32Array(_j, p, "slots");
        uint256 headAfter = _uint(_j, _in, "forced_inclusion_head_after");
        bytes32 lastBlockHash = _bytes32(_j, _in, "last_block_hash");
        assertEq(
            vm.load(_target, slots[0]),
            bytes32(_c | (_uint(_j, _in, "generation") << 48) | (headAfter << 96)),
            "record word 1"
        );
        assertEq(vm.load(_target, slots[1]), lastBlockHash, "record EL hash");
        assertEq(
            vm.load(_target, slots[2]), _bytes32(_j, _in, "last_comet_hash"), "record Comet hash"
        );
        assertEq(
            uint256(vm.load(_target, bytes32(_inboxSlot(_j, "last_checkpoint_height")))),
            18,
            "checkpoint height"
        );
        assertEq(
            vm.load(_target, bytes32(_inboxSlot(_j, "last_checkpoint_hash"))),
            lastBlockHash,
            "checkpoint hash"
        );
        (uint48 head,) = IEtnaInbox(_target).getForcedInclusionState();
        assertEq(head, headAfter, "queue head");
        // The root-only SignalService keeps the state root and returns no hash.
        assertEq(signalService.getCheckpoint(18).blockHash, 0, "signal block hash");
        assertEq(
            signalService.getCheckpoint(18).stateRoot,
            _bytes32(_j, _in, "last_state_root"),
            "signal state root"
        );
    }

    /// @dev Lands the genesis statement vector's (0, 18] inputs with `_leaves` on the vector Inbox
    /// `_target` from checkpoint `_c`, with a verifier accepting only the vector statement hash and
    /// expecting `Landed(0, _c, 18, cutHash, 1)`, then checks the writes.
    function _landGenesisVectorFrom(
        string memory _j,
        address _target,
        bytes32[] memory _leaves,
        uint256 _c
    )
        private
    {
        string memory s = ".land_statements[0].";
        string memory input = string.concat(s, "inputs.");
        IEtnaInbox.LandInput memory landInput = _landInput(_j, input);
        bytes memory proof = _bytes(_j, ".land_abi.", "proof");
        bytes32 statement = _bytes32(_j, s, "hash");
        assertEq(IEtnaInbox(_target).lastCheckpoint().height, _c, "checkpoint above the origin");
        landVerifier.setExpectedStatementHash(statement);

        vm.blobhashes(_bytes32Array(_j, input, "blob_hashes"));
        vm.expectCall(
            address(landVerifier), abi.encodeCall(IProofVerifier.verifyProof, (0, statement, proof))
        );
        vm.expectEmit(_target);
        emit IEtnaInbox.Landed(0, _c, 18, _bytes32(_j, input, "cut_hash"), 1);
        IEtnaInbox(_target).land(landInput, _leaves, proof);

        _assertVectorLanding(_j, _target, input, _c);
    }

    /// @dev Expects the genesis statement vector's (0, 18] inputs with `_leaves` to revert with
    /// `FrontierLeafMismatch` on the vector Inbox `_target`.
    function _expectVectorFrontierLeafMismatch(
        string memory _j,
        address _target,
        bytes32[] memory _leaves
    )
        private
    {
        string memory input = ".land_statements[0].inputs.";
        vm.blobhashes(_bytes32Array(_j, input, "blob_hashes"));
        vm.expectRevert(IEtnaInbox.FrontierLeafMismatch.selector);
        IEtnaInbox(_target).land(_landInput(_j, input), _leaves, _bytes(_j, ".land_abi.", "proof"));
    }

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
}
