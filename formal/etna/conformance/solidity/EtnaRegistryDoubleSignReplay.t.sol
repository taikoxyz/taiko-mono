// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { EtnaRegistryCasesBase } from "./EtnaRegistryCasesBase.sol";

/// @dev Actual encoder and real Registry evidence consumers for pinned public votes.
contract EtnaRegistryDoubleSignReplayTest is EtnaRegistryCasesBase {
    bytes32 private constant _PRE_ROOT =
        0x127f676de3068bcb8bf2dce40cc698fb6b1ca017ca1c81f2e71a0d6ac49f9813;
    bytes32 private constant _POST_ROOT =
        0x966d420734f3bd7301e9c5432191a6ec82bb3367c615ca4282ba7bbe41dce959;
    bytes4 private constant _NOT_DOUBLE_SIGN = bytes4(keccak256("NotDoubleSign()"));
    bytes4 private constant _FUTURE = bytes4(keccak256("FutureGeneration()"));
    bytes4 private constant _SIGNATURE = bytes4(keccak256("InvalidSignature()"));
    bytes4 private constant _SPENT = bytes4(keccak256("NothingToSlash()"));

    struct EvidenceCase {
        uint256 first;
        uint256 second;
        uint48 current;
        bytes4 error;
        uint48 generation;
        uint32 round;
        uint8 voteType;
    }

    struct PairReceipt {
        address firstProxy;
        address repeatProxy;
        bytes4 firstResult;
        bytes4 repeatResult;
        uint256 generation;
        bytes32 beforeState;
        bytes32 afterState;
        bytes32 repeatState;
        bytes32 preRoot;
        bytes32 postRoot;
        uint256 custody;
        uint256 reporter;
        uint256 sink;
        uint256 ownerCash;
        uint256 allowance;
        uint256 transfers;
        uint256 firstLogs;
        uint256 repeatLogs;
        uint256 pending;
        uint256 ready;
        uint256 admission;
    }

    string private _votes;

    /// @dev Read one typed projection containing public literals exclusively.
    function setUp() external {
        _votes = VM.readFile("test/layer1/etna/conformance/vectors/comet_signed/public-votes.json");
    }

    /// @dev Compare actual library output with both published preimage and digest/ID literals.
    function _domain(uint256 _index) private {
        string memory row = _rowPath(".chainDomains", _index);
        uint256 l1 = _number(row, ".l1_chain_id");
        uint256 l2 = _number(row, ".l2_chain_id");
        address domainInbox = VM.parseJsonAddress(_votes, string.concat(row, ".inbox"));
        uint48 generation = uint48(_number(row, ".generation"));
        bytes memory preimage = abi.encode(bytes32("ETNA_COMET_DOMAIN_V1"), l1, l2, domainInbox, generation);
        require(
            keccak256(preimage) == keccak256(VM.parseJsonBytes(_votes, string.concat(row, ".preimage"))),
            "N02 domain: exact published five-word preimage"
        );
        bytes32 digest = LibCometVote.chainDomain(l1, l2, domainInbox, generation);
        require(
            digest == keccak256(preimage)
                && digest == VM.parseJsonBytes32(_votes, string.concat(row, ".chain_domain")),
            "N02 domain: exact published digest"
        );
        bytes memory id = LibCometVote.chainId(digest);
        require(
            id.length == 48 && keccak256(id)
                == keccak256(bytes(VM.parseJsonString(_votes, string.concat(row, ".chain_id")))),
            "N02 domain: exact published chain ID"
        );
        emit RegistryCaseReceipt(abi.encodePacked(digest, id));
    }

    /// @dev Return the exact uint64 timestamp bits separately from the signed projection field.
    function _vote(string memory _row) private view returns (IEtnaStakingRegistry.Vote memory vote) {
        return _publicVote(_votes, _row);
    }

    /// @dev N01 hashes and strict adapter bounds protect the narrowing conversions.
    function _number(string memory _row, string memory _field) private view returns (uint256) {
        return VM.parseUint(VM.parseJsonString(_votes, string.concat(_row, _field)));
    }

    /// @dev Compare actual canonical bytes directly against the published literal.
    function _wire(uint256 _index) private {
        string memory row = _rowPath(".voteCases", _index);
        bytes memory actual = LibCometVote.signBytes(
            _vote(row), bytes(VM.parseJsonString(_votes, string.concat(row, ".chain_id")))
        );
        require(
            keccak256(actual) == keccak256(VM.parseJsonBytes(_votes, string.concat(row, ".sign_bytes"))),
            "N02 wire: exact published canonical bytes"
        );
        emit RegistryCaseReceipt(actual);
    }

    /// @dev Build lawful principal through public PoP registration and a pending top-up.
    function _prepare(uint48 _current) private returns (PublicPoP memory pop) {
        _setupRegistry(_current);
        pop = _publicPoP(0);
        require(
            pop.signer == VM.parseJsonAddress(_votes, ".voteKey.signer")
                && keccak256(pop.key) == keccak256(VM.parseJsonBytes(_votes, ".voteKey.public_key")),
            "N02 setup: published vote key is the registered key"
        );
        _fund(pop.owner, 100, 100);
        require(_register(pop, 4) == 0, "N02 setup: bond zero");
        VM.roll(12);
        VM.prank(pop.owner);
        registry.topUp(0, 4);
        VM.roll(13);
        _checkState(pop, false);
    }

    /// @dev Independent literal principal, roots, history, cash and lifetime identity.
    function _checkState(PublicPoP memory _pop, bool _slashed) private view {
        IEtnaStakingRegistry.Entry memory entry = IEtnaStakingRegistry.Entry(
            _pop.x, _slashed ? 0 : 4, _pop.prefix, 12, _slashed ? 13 : NO_EXIT
        );
        bytes32 root = _slashed ? _POST_ROOT : _PRE_ROOT;
        uint256 count = _slashed ? 2 : 1;
        require(_leaf(0, entry) == root, "N02 history: independent literal root");
        require(
            registry.entriesRoot() == root && _rawMap(R + 2, 0) == root
                && registry.checkpointCount() == count && _raw(R) == bytes32(count),
            "N02 history: root and count"
        );
        _requireCheckpoint(0, 10, 1, _PRE_ROOT);
        if (_slashed) _requireCheckpoint(1, 13, 1, _POST_ROOT);
        uint256 bond = _mapSlot(R + 6, 0);
        _requireEntry(bond, entry);
        _requireEntry(uint256(keccak256(abi.encode(R + 1))), entry);
        require(
            _raw(R + 1) == bytes32(uint256(1)) && registry.entryCount() == 1
                && _raw(R + 7) == bytes32(uint256(1)) && registry.bondCount() == 1
                && _raw(bond + 3) == bytes32(uint256(1 << 16))
                && _rawMap(R + 4, uint160(_pop.signer)) == bytes32(uint256(1))
                && _rawMap(R + 5, 0) == bytes32(uint256(1))
                && _rawMap(OWNERS, 0) == bytes32(uint256(uint160(_pop.owner)))
                && _rawMap(CONFIRM, 0) == 0 && _rawMap(FORFEIT, uint256(_pop.entryKey)) == 0,
            "N02 identity: lifetime key, owner and retained slot"
        );
        (bool registered, uint256 keyBond) = registry.bondForKey(_pop.signer);
        (bool occupied, uint256 slotBond) = registry.bondInSlot(0);
        (bool holds, uint256 bondSlot) = registry.slotOfBond(0);
        require(registered && occupied && holds && keyBond == 0 && slotBond == 0 && bondSlot == 0,
            "N02 identity: bidirectional lookup");
        require(
            _rawMap(TOP, 0) == bytes32(uint256(_slashed ? 0 : 4))
                && _raw(_mapSlot(TOP, 0) + 1) == bytes32(uint256(_slashed ? 0 : 14))
                && _rawMap(R + 3, 4096) == bytes32(uint256(_slashed ? 0 : 8 << 12))
                && _rawMap(R + 3, 1) == bytes32(uint256(_slashed ? 0 : 1)),
            "N02 principal: pending, ready and admission"
        );
        require(
            _balance(REPORTER) == (_slashed ? 2 : 0) && _balance(SINK) == (_slashed ? 6 : 0),
            "N02 payout: exact reporter and sink"
        );
        require(
            _balance(REGISTRY) == (_slashed ? 0 : 8) && _balance(_pop.owner) == 92
                && _allowance(_pop.owner) == 92 && _transfers() == (_slashed ? 4 : 2),
            "N02 cash: exact custody, owner, allowance and transfers"
        );
    }

    /// @dev Match the complete four-log sequence after actual slashing.
    function _successLogs(Vm.Log[] memory _logs, uint48 _generation, uint32 _round, uint8 _type)
        private
        view
    {
        bytes32[] memory expected = new bytes32[](4);
        expected[0] = _checkpointEvent(1, 13, 1, _POST_ROOT);
        expected[1] = _transferEvent(REGISTRY, REPORTER, 2);
        expected[2] = _transferEvent(REGISTRY, SINK, 6);
        bytes32[] memory topics = new bytes32[](3);
        topics[0] = keccak256("DoubleSignSlashed(uint256,address,uint256,uint256,uint48,uint64,uint32,uint8)");
        topics[1] = 0;
        topics[2] = bytes32(uint256(uint160(REPORTER)));
        expected[3] = _event(REGISTRY, topics, abi.encode(8, 2, _generation, uint64(1000), _round, _type));
        _requireEvents(_logs, expected);
    }

    /// @dev Apply two exact calls against fresh legal stake and record independent observations.
    function _pair(string memory _name, EvidenceCase memory _case) private {
        PublicPoP memory pop = _prepare(_case.current);
        PairReceipt memory receipt;
        receipt.generation = inbox.recoveryGeneration();
        receipt.preRoot = registry.entriesRoot();
        receipt.beforeState = _stateDigest();
        bytes memory action = abi.encodeCall(registry.slashDoubleSign, (
            0, _vote(_rowPath(".voteCases", _case.first)), _vote(_rowPath(".voteCases", _case.second))
        ));
        CallResult memory first = _callRegistry(REPORTER, action);
        bytes memory observedFirst;
        (receipt.firstProxy, observedFirst) = _registryFrame(first, REPORTER, action);
        receipt.firstResult = bytes4(first.data);
        receipt.firstLogs = first.logs.length;
        if (_case.first == 0 && _case.second == 3) {
            require(!first.ok, "N02 same_block_later_time: expected NotDoubleSign, got success");
        }
        bool slashed = _case.error == 0;
        if (slashed) {
            require(first.ok && first.data.length == 0, "N02 slash: designated evidence must succeed");
            _checkState(pop, true);
            _successLogs(first.logs, _case.generation, _case.round, _case.voteType);
        }
        receipt.afterState = _stateDigest();
        if (!slashed) {
            _requireRefusal(first, abi.encodePacked(_case.error), receipt.beforeState, receipt.afterState,
                new bytes32[](0));
        }
        CallResult memory repeat = _callRegistry(REPORTER, action);
        bytes memory observedRepeat;
        (receipt.repeatProxy, observedRepeat) = _registryFrame(repeat, REPORTER, action);
        receipt.repeatResult = bytes4(repeat.data);
        receipt.repeatLogs = repeat.logs.length;
        receipt.repeatState = _stateDigest();
        _requireRefusal(repeat, abi.encodePacked(slashed ? _SPENT : _case.error), receipt.afterState,
            receipt.repeatState, new bytes32[](0));
        _checkState(pop, slashed);

        receipt.postRoot = registry.entriesRoot();
        receipt.custody = _balance(REGISTRY);
        receipt.reporter = _balance(REPORTER);
        receipt.sink = _balance(SINK);
        receipt.ownerCash = _balance(pop.owner);
        receipt.allowance = _allowance(pop.owner);
        receipt.transfers = _transfers();
        receipt.pending = uint256(_rawMap(TOP, 0));
        receipt.ready = uint256(_raw(_mapSlot(TOP, 0) + 1));
        receipt.admission = uint256(_rawMap(R + 3, 4096));
        emit RegistryCaseReceipt(bytes.concat(abi.encode(receipt), abi.encode(_name, observedFirst, observedRepeat)));
    }

    /// @dev Actual domain and canonical-byte leaves are individually selected by exact identity.
    function test_domain_local_generation_0() external { _domain(0); }
    function test_domain_local_generation_1() external { _domain(1); }
    function test_domain_local_generation_2() external { _domain(2); }
    function test_domain_local_generation_max() external { _domain(3); }
    function test_domain_foreign_inbox() external { _domain(4); }

    /// @dev One leaf per published signed row.
    function test_wire_precommit_a() external { _wire(0); }
    function test_wire_precommit_nil() external { _wire(1); }
    function test_wire_precommit_b() external { _wire(2); }
    function test_wire_precommit_a_late() external { _wire(3); }
    function test_wire_prevote_a_r1() external { _wire(4); }
    function test_wire_prevote_b_r1() external { _wire(5); }
    function test_wire_prevote_b_r2() external { _wire(6); }
    function test_wire_precommit_b_r1() external { _wire(7); }
    function test_wire_gen1_precommit_a() external { _wire(8); }
    function test_wire_gen1_precommit_b() external { _wire(9); }
    function test_wire_gen2_precommit_a() external { _wire(10); }
    function test_wire_gen2_precommit_b() external { _wire(11); }
    function test_wire_other_inbox_precommit_b() external { _wire(12); }
    function test_wire_partial_block_id() external { _wire(13); }
    function test_wire_max_values() external { _wire(14); }
    function test_wire_precommit_b_h1001() external { _wire(15); }
    function test_wire_hash_only_block_id() external { _wire(16); }
    function test_wire_zero_timestamp() external { _wire(17); }
    function test_wire_negative_timestamp() external { _wire(18); }
    function test_wire_min_timestamp() external { _wire(19); }
    function test_wire_max_timestamp_seconds() external { _wire(20); }
    function test_wire_precommit_a_backdated() external { _wire(21); }
    function test_wire_precommit_b_backdated() external { _wire(22); }

    /// @dev Each leaf deploys a fresh Registry and executes the exact same evidence twice.
    function test_pair_precommit_conflict() external {
        _pair("precommit_conflict", EvidenceCase(0, 2, 0, bytes4(0), 0, 0, 2));
    }
    function test_pair_precommit_vs_nil() external {
        _pair("precommit_vs_nil", EvidenceCase(0, 1, 0, bytes4(0), 0, 0, 2));
    }
    function test_pair_prevote_conflict_round_1() external {
        _pair("prevote_conflict_round_1", EvidenceCase(4, 5, 0, bytes4(0), 0, 1, 1));
    }
    function test_pair_same_block_later_time() external {
        _pair("same_block_later_time", EvidenceCase(0, 3, 0, _NOT_DOUBLE_SIGN, 0, 0, 0));
    }
    function test_pair_different_round() external {
        _pair("different_round", EvidenceCase(5, 6, 0, _NOT_DOUBLE_SIGN, 0, 0, 0));
    }
    function test_pair_different_type() external {
        _pair("different_type", EvidenceCase(4, 7, 0, _NOT_DOUBLE_SIGN, 0, 0, 0));
    }
    function test_pair_generation_1_conflict() external {
        _pair("generation_1_conflict", EvidenceCase(8, 9, 1, bytes4(0), 1, 0, 2));
    }
    function test_pair_historical_generation_conflict() external {
        _pair("historical_generation_conflict", EvidenceCase(0, 2, 1, bytes4(0), 0, 0, 2));
    }
    function test_pair_future_generation() external {
        _pair("future_generation", EvidenceCase(10, 11, 1, _FUTURE, 0, 0, 0));
    }
    function test_pair_other_deployment() external {
        _pair("other_deployment", EvidenceCase(0, 12, 0, _SIGNATURE, 0, 0, 0));
    }
    function test_pair_different_round_conflicting_blocks() external {
        _pair("different_round_conflicting_blocks", EvidenceCase(4, 6, 0, _NOT_DOUBLE_SIGN, 0, 0, 0));
    }
    function test_pair_different_generation() external {
        _pair("different_generation", EvidenceCase(0, 9, 1, _NOT_DOUBLE_SIGN, 0, 0, 0));
    }
    function test_pair_different_height() external {
        _pair("different_height", EvidenceCase(0, 15, 0, _NOT_DOUBLE_SIGN, 0, 0, 0));
    }
    function test_pair_backdated_conflict() external {
        _pair("backdated_conflict", EvidenceCase(21, 22, 0, bytes4(0), 0, 0, 2));
    }
}
