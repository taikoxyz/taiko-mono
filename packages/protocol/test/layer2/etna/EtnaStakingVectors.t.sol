// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { EtnaStaking } from "src/layer2/etna/EtnaStaking.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { LibCometVote } from "src/layer2/etna/libs/LibCometVote.sol";
import { LibEtnaKeys } from "src/shared/etna/LibEtnaKeys.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";
import { EtnaVectorReader, LibEtnaVectors } from "test/shared/etna/LibEtnaVectors.sol";

/// @title EtnaStakingVectorsTest
/// @notice Pins the staking contract's storage (spec appendix B), block-start call, registration
/// digest, vote encodings, forfeiture rounding and ABI to `testdata/etna_vectors/vectors.json`,
/// the file the Etna node and guests read.
/// @dev The tests that need the vector address etch the implementation at chain 167001's genesis
/// implementation address and the proxy at the vector staking address, which every vector proof
/// of possession and digest binds; the others use a proxy at another address, since nothing they
/// compare depends on it. Each test loads the file into memory (`j`).
contract EtnaStakingVectorsTest is EtnaStakingTestBase, EtnaVectorReader {
    /// @dev The staking implementation of chain 167001's genesis: getConstantAddress("0167001",
    /// 10003).
    address private constant _VECTOR_IMPL = 0x0167001000000000000000000000000000010003;

    /// @dev The EIP-1967 implementation slot.
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The X of K1 and K2, the compressed keys of private keys 1 and 2 (prefix 0x02).
    bytes32 private constant _K1_X =
        0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798;
    bytes32 private constant _K2_X =
        0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5;

    /// @dev The incident id and deadline the vector forfeiture carries.
    bytes32 private constant _INCIDENT_ID = bytes32(uint256(42));
    uint256 private constant _VALID_UNTIL = 1_700_000_123;

    /// @dev The owner the vector proofs of possession of `register_digests` item 0 are bound to.
    address private constant _OWNER_AA = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;

    // ---------------------------------------------------------------
    // Registration digest and proof of possession
    // ---------------------------------------------------------------

    /// @dev At the vector address on chain 167001, `registerDigest(owner)` is each case's digest:
    /// the EIP-712 hash of `Register(address owner)` under the domain EtnaStaking, version 1, the
    /// L2 chain id and the staking proxy. The cases run key by key, both owners each, and each
    /// proof of possession recovers to its key's address.
    function test_registerDigest_MatchesAtTheVectorAddress() external {
        string memory j = LibEtnaVectors.load();
        _etchVectorStaking(j);
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("EtnaStaking"),
                keccak256("1"),
                block.chainid,
                address(staking)
            )
        );

        uint256 n = LibEtnaVectors.lengthAt(j, ".register_digests");
        assertEq(n, 2 * LibEtnaVectors.lengthAt(j, ".keys"), "two owners per key");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".register_digests", i);
            string memory name = _string(j, p, "name");
            assertEq(_uint(j, p, "l2_chain_id"), block.chainid, name);
            assertEq(_address(j, p, "staking"), address(staking), name);
            assertEq(_bytes32(j, p, "domain_separator"), domainSeparator, name);
            bytes32 structHash = keccak256(
                abi.encode(keccak256("Register(address owner)"), _address(j, p, "owner"))
            );
            assertEq(_bytes32(j, p, "struct_hash"), structHash, name);
            bytes32 digest = staking.registerDigest(_address(j, p, "owner"));
            assertEq(digest, _bytes32(j, p, "digest"), name);
            assertEq(
                digest, keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash)), name
            );
            string memory key = _at(".keys", i / 2);
            assertEq(_bytes(j, p, "key"), _bytes(j, key, "public_key"), name);
            assertEq(
                LibEtnaKeys.recoverSigner(digest, _bytes(j, p, "pop_sig")),
                _address(j, key, "ck_addr"),
                name
            );
        }
    }

    /// @dev Every `register_digests` proof of possession registers its key for its owner at the
    /// vector staking contract, each case from the same fresh state: bond 0 in seat 0, with the
    /// key's prefix and X.
    function test_register_AcceptsVectorPop() external {
        string memory j = LibEtnaVectors.load();
        _etchVectorStaking(j);
        uint256 n = LibEtnaVectors.lengthAt(j, ".register_digests");
        assertEq(n, 12, "cases");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".register_digests", i);
            string memory name = _string(j, p, "name");
            string memory key = _at(".keys", i / 2);
            address owner = _address(j, p, "owner");
            uint256 fresh = vm.snapshotState();
            _fund(owner, MIN_STAKE);

            vm.prank(owner);
            assertEq(
                staking.register(_bytes(j, p, "key"), MIN_STAKE, _bytes(j, p, "pop_sig")), 0, name
            );
            IEtnaStaking.Bond memory bond = staking.bondAt(0);
            assertEq(bond.owner, owner, name);
            assertEq(bond.ckPrefix, _uint(j, key, "ck_prefix"), name);
            assertEq(bond.ckX, _bytes32(j, key, "ck_x"), name);
            _assertBondForKey(_address(j, key, "ck_addr"), true, 0, name);
            _assertSeatOfBond(0, true, 0, name);
            vm.revertToState(fresh);
        }
    }

    /// @dev Every `pop_rejections` case reverts with `InvalidSignature` at the vector staking
    /// contract, the one domain where the case's original proof of possession is valid, and
    /// issues no bond; the control, `register_digests` item 0 (key a1 for owner 0xaaaa…aa),
    /// registers there afterwards.
    function test_register_RevertWhen_VectorPopInvalid() external {
        string memory j = LibEtnaVectors.load();
        _etchVectorStaking(j);
        uint256 n = LibEtnaVectors.lengthAt(j, ".pop_rejections");
        assertEq(n, 14, "cases");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".pop_rejections", i);
            address owner = _address(j, p, "owner");
            _fund(owner, MIN_STAKE);
            bytes memory publicKey = _bytes(j, p, "public_key");
            bytes memory pop = _bytes(j, p, "pop_sig");
            vm.expectRevert(LibEtnaKeys.InvalidSignature.selector);
            vm.prank(owner);
            staking.register(publicKey, MIN_STAKE, pop);
        }
        assertEq(staking.bondCount(), 0, "no bond issued");

        string memory control = ".register_digests[0].";
        assertEq(_bytes(j, control, "key"), _bytes(j, ".keys[0].", "public_key"), "key a1");
        assertEq(_address(j, control, "owner"), _OWNER_AA, "owner 0xaa");
        _fund(_OWNER_AA, MIN_STAKE);
        vm.prank(_OWNER_AA);
        staking.register(_bytes(j, control, "key"), MIN_STAKE, _bytes(j, control, "pop_sig"));
        assertEq(staking.bondAt(0).owner, _OWNER_AA, "control registered");
    }

    // ---------------------------------------------------------------
    // Storage layout
    // ---------------------------------------------------------------

    /// @dev The namespace base T, the snapshot words, the key-to-seat mapping, the record slots,
    /// the EIP-1967 slot and the no-exit value are the contract's; the key-to-seat words decode
    /// to a seat exactly as the vectors say (null for none). Live, keys a1-a5 register in seats
    /// 0-4 with their vector proofs and K1 then takes seat 5: the words at the vector key slots
    /// and, after a block-start call, the snapshot words are what `vm.load` reads.
    function test_stakingLayout_SlotsAndWordsMatchContractStorage() external {
        string memory j = LibEtnaVectors.load();
        string memory s = ".staking_layout.";
        _etchVectorStaking(j);
        assertEq(_string(j, s, "namespace"), "taiko.etna.staking", "namespace");
        assertEq(_bytes32(j, s, "base"), _erc7201("taiko.etna.staking"), "base");
        assertEq(_bytes32(j, s, "base"), T, "T");
        assertEq(_bytes32(j, s, "snapshot_height_slot"), T, "snapshotHeight at T");
        assertEq(uint256(_bytes32(j, s, "snapshot_total_stake_slot")), uint256(T) + 1, "T + 1");
        assertEq(uint256(_bytes32(j, s, "key_seat_slot")), uint256(T) + 2, "T + 2");
        assertEq(_bytes32(j, s, "implementation_slot"), _IMPLEMENTATION_SLOT, "EIP-1967 slot");
        assertEq(
            vm.load(address(staking), _IMPLEMENTATION_SLOT),
            bytes32(uint256(uint160(_VECTOR_IMPL))),
            "the proxy's implementation"
        );
        assertEq(_uint(j, s, "no_exit"), staking.NO_EXIT(), "no exit");

        _assertRecordSlots(j, s);
        _assertKeySeatWords(j, s);
        _assertRecordWords(j, s);

        // Keys a1-a5 in seats 0-4, then K1 in seat 5.
        for (uint256 k; k < 5; ++k) {
            string memory p = _at(".register_digests", 2 * k);
            assertEq(_bytes(j, p, "key"), _bytes(j, _at(".keys", k), "public_key"), "key order");
            address owner = _address(j, p, "owner");
            _fund(owner, MIN_STAKE);
            vm.prank(owner);
            staking.register(_bytes(j, p, "key"), MIN_STAKE, _bytes(j, p, "pop_sig"));
            _assertSeatOfBond(k, true, uint8(k), "vector key seat");
        }
        uint256 k1 = _register(1, Bob, MIN_STAKE);
        _assertSeatOfBond(k1, true, 5, "K1 takes seat 5");

        string memory slots = string.concat(s, "key_seat_slots");
        assertEq(LibEtnaVectors.lengthAt(j, slots), 6, "key slots");
        assertEq(_address(j, _at(slots, 0), "ck_addr"), EtnaTestKeys.ckAddr(1), "K1");
        assertEq(_address(j, _at(slots, 1), "ck_addr"), EtnaTestKeys.ckAddr(2), "K2");
        bytes32 k1Slot = _bytes32(j, _at(slots, 0), "slot");
        assertEq(vm.load(address(staking), k1Slot), _bytes32(j, s, "key_seat_words[0].word"));
        assertEq(_uint(j, s, "key_seat_words[0].seat"), 5, "the K1 word names seat 5");
        assertEq(vm.load(address(staking), _bytes32(j, _at(slots, 1), "slot")), 0, "K2 is unused");
        for (uint256 k; k < 4; ++k) {
            string memory p = _at(slots, 2 + k);
            assertEq(_address(j, p, "ck_addr"), _address(j, _at(".keys", k), "ck_addr"), "a_k");
            assertEq(
                vm.load(address(staking), _bytes32(j, p, "slot")),
                bytes32((k << 8) | 1),
                "a_k holds seat k"
            );
        }

        _blockStart(0, 0);
        assertEq(uint256(vm.load(address(staking), T)), block.number, "snapshotHeight");
        assertEq(
            uint256(vm.load(address(staking), bytes32(uint256(T) + 1))),
            6 * MIN_STAKE,
            "snapshotTotalStake"
        );
        string memory seat5 = string.concat(s, "record_slots[1].");
        assertEq(_uint(j, seat5, "seat"), 5, "record slots of seat 5");
        assertEq(vm.load(address(staking), _bytes32(j, seat5, "word1")), _K1_X, "seat 5 ckX");
        assertEq(
            uint256(vm.load(address(staking), _bytes32(j, seat5, "word2"))),
            2 | ((MIN_STAKE / VP_UNIT) << 8),
            "seat 5 prefix and power"
        );
        string memory seat127 = string.concat(s, "record_slots[2].");
        assertEq(vm.load(address(staking), _bytes32(j, seat127, "word1")), 0, "seat 127 empty");
        assertEq(vm.load(address(staking), _bytes32(j, seat127, "word2")), 0, "seat 127 empty");

        _requestExit(k1);
        assertEq(vm.load(address(staking), k1Slot), 0, "K1 has no seat after its exit");
    }

    // ---------------------------------------------------------------
    // The block-start call
    // ---------------------------------------------------------------

    /// @dev Every `on_block_start` case on a fresh staking contract with the case's overrides:
    /// the registrations at block 1000 - k - 1, the k prior calls in the blocks before 1000 and
    /// the call at 1000 (the block numbers are this suite's; nothing expected depends on them).
    /// Every expected field is compared: every seat's miss count, every bond's effStake and seat,
    /// the penalty sent to slashSink, all 128 records, the snapshot words and the generation. Gas
    /// metering is paused: the cases deploy a contract each, beyond the block gas limit a test runs
    /// under, and nothing compared depends on gas.
    function test_onBlockStart_ReplaysEveryVectorCase() external {
        vm.pauseGasMetering();
        string memory j = LibEtnaVectors.load();
        string memory d = ".on_block_start.deployment.";
        assertEq(_uint(j, d, "n_max"), N_MAX, "nMax");
        assertEq(_uint(j, d, "min_stake"), MIN_STAKE, "minStake");
        assertEq(_uint(j, d, "vp_unit"), VP_UNIT, "vpUnit");
        assertEq(_uint(j, d, "miss_limit"), MISS_LIMIT, "missLimit");
        assertEq(_uint(j, d, "miss_slash_bps"), MISS_SLASH_BPS, "missSlashBps");

        string memory list = ".on_block_start.cases";
        uint256 n = LibEtnaVectors.lengthAt(j, list);
        assertEq(n, 16, "cases");
        for (uint256 i; i < n; ++i) {
            uint256 fresh = vm.snapshotState();
            uint256 mark = _freeMemory();
            _replayOnBlockStart(j, _at(list, i));
            _releaseMemory(mark);
            vm.revertToState(fresh);
        }
    }

    /// @dev Every `extra_data` row's block-start calldata is `onBlockStart` of the row's
    /// generation and missBitmap, which are bytes 1-6 and 13-28 of its extraData, and stores
    /// that generation; the spec's calldata and selector examples are Solidity's.
    function test_onBlockStart_CalldataEqualsTheExtraDataRows() external {
        string memory j = LibEtnaVectors.load();
        string memory a = ".appendix_a_examples.";
        assertEq(
            _bytes(j, string.concat(a, "enc_a_10d_b."), "selector"),
            abi.encodePacked(IEtnaStaking.onBlockStart.selector),
            "selector"
        );
        assertEq(
            bytes4(keccak256(bytes(_string(j, string.concat(a, "enc_a_10d_b."), "signature")))),
            IEtnaStaking.onBlockStart.selector,
            "signature"
        );
        assertEq(
            _bytes(j, string.concat(a, "enc_a_10d_a."), "calldata"),
            abi.encodeCall(IEtnaStaking.onBlockStart, (1, 5)),
            "calldata example"
        );

        uint256 n = LibEtnaVectors.lengthAt(j, ".extra_data");
        assertEq(n, 5, "rows");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".extra_data", i);
            uint48 generation = uint48(_uint(j, p, "generation"));
            uint128 missBitmap = uint128(_uint(j, p, "miss_bitmap"));
            bytes memory data = _bytes(j, p, "on_block_start_calldata");
            assertEq(data.length, 68, "68 bytes");
            assertEq(data, abi.encodeCall(IEtnaStaking.onBlockStart, (generation, missBitmap)));

            bytes memory extraData = _bytes(j, p, "extra_data");
            assertEq(extraData.length, 29, "29 bytes");
            assertEq(uint8(extraData[0]), 0x64, "version byte");
            assertEq(_bigEndian(extraData, 1, 6), generation, "generation bytes");
            assertEq(_bigEndian(extraData, 7, 6), _uint(j, p, "anchor_number"), "anchor bytes");
            assertEq(_bigEndian(extraData, 13, 16), missBitmap, "missBitmap bytes");

            vm.roll(block.number + 1);
            vm.prank(SYSTEM_CALLER);
            (bool ok,) = address(staking).call(data);
            assertTrue(ok, "the call succeeds");
            assertEq(staking.lastGeneration(), generation, "generation stored");
        }
    }

    // ---------------------------------------------------------------
    // Votes and chain domains
    // ---------------------------------------------------------------

    /// @dev Every vote case's CometBFT sign bytes are `LibCometVote.signBytes` of the vote under
    /// its chain id, and its signature recovers to the vector key. At the vector staking contract,
    /// with that key registered as bond 0 and each pair's generation stored by a block-start
    /// call, every double-sign pair slashes the whole stake and every other pair reverts with
    /// the error of its reason. Gas metering is paused: each read copies the whole document into
    /// the cheatcode call, and the reads of 29 votes and 20 pairs come near the block gas limit a
    /// test runs under; nothing compared depends on gas.
    function test_votes_SignBytesAndFailuresMatch() external {
        vm.pauseGasMetering();
        string memory j = LibEtnaVectors.load();
        string memory key = ".votes.key.";
        address signer = _address(j, key, "signer");
        assertEq(EtnaTestKeys.publicKey(_uint(j, key, "private_key")), _bytes(j, key, "public_key"));

        string[] memory names = _voteNames(j);
        assertEq(names.length, 29, "vote cases");
        for (uint256 i; i < names.length; ++i) {
            uint256 mark = _freeMemory();
            string memory p = _at(".votes.cases", i);
            IEtnaStaking.Vote memory vote = _vectorVote(j, names, names[i]);
            bytes memory signBytes = LibCometVote.signBytes(vote, bytes(_string(j, p, "chain_id")));
            assertEq(signBytes, _bytes(j, p, "sign_bytes"), names[i]);
            assertEq(LibEtnaKeys.recoverSigner(keccak256(signBytes), vote.signature), signer);
            _releaseMemory(mark);
        }

        _etchVectorStaking(j);
        string memory control = ".register_digests[0].";
        assertEq(_bytes(j, control, "key"), _bytes(j, key, "public_key"), "the vote key");
        _fund(_OWNER_AA, MIN_STAKE);
        vm.prank(_OWNER_AA);
        staking.register(_bytes(j, control, "key"), MIN_STAKE, _bytes(j, control, "pop_sig"));

        uint256 n = LibEtnaVectors.lengthAt(j, ".votes.pairs");
        assertEq(n, 20, "pairs");
        uint256 slashed;
        for (uint256 i; i < n; ++i) {
            uint256 fresh = vm.snapshotState();
            uint256 mark = _freeMemory();
            if (_checkPair(j, names, _at(".votes.pairs", i))) ++slashed;
            _releaseMemory(mark);
            vm.revertToState(fresh);
        }
        assertEq(slashed, 12, "double-sign pairs");
    }

    /// @dev Every chain domain is keccak256 of its five-word preimage and `LibCometVote`'s
    /// `chainDomain` of its inputs, and its CometBFT chain id is the 48-byte "etna-" encoding;
    /// the vote chain ids are those of the vector deployment's domains.
    function test_chainDomains_Match() external view {
        string memory j = LibEtnaVectors.load();
        assertEq(staking.l1ChainId(), _uint(j, ".deployment.", "l1_chain_id"), "L1 chain");
        assertEq(staking.inbox(), _address(j, ".deployment.", "inbox"), "Inbox");
        uint256 n = LibEtnaVectors.lengthAt(j, ".chain_domains");
        assertEq(n, 5, "domains");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".chain_domains", i);
            uint256 l1ChainId = _uint(j, p, "l1_chain_id");
            uint256 l2ChainId = _uint(j, p, "l2_chain_id");
            address inbox = _address(j, p, "inbox");
            uint48 generation = uint48(_uint(j, p, "generation"));
            bytes memory preimage = abi.encode(
                bytes32("ETNA_COMET_DOMAIN_V1"), l1ChainId, l2ChainId, inbox, generation
            );
            assertEq(preimage.length, 160, "five words");
            assertEq(preimage, _bytes(j, p, "preimage"), "preimage");
            bytes32 domain = LibCometVote.chainDomain(l1ChainId, l2ChainId, inbox, generation);
            assertEq(domain, keccak256(preimage), "chainDomain");
            assertEq(domain, _bytes32(j, p, "chain_domain"), "vector domain");
            bytes memory chainId = LibCometVote.chainId(domain);
            assertEq(chainId.length, 48, "48 bytes");
            assertEq(string(chainId), _string(j, p, "chain_id"), "chain id");
        }

        n = LibEtnaVectors.lengthAt(j, ".votes.chain_ids");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".votes.chain_ids", i);
            bytes32 domain = LibCometVote.chainDomain(
                L1_CHAIN_ID,
                block.chainid,
                _address(j, p, "inbox"),
                uint48(_uint(j, p, "generation"))
            );
            assertEq(string(LibCometVote.chainId(domain)), _string(j, p, "chain_id"), "vote");
        }
    }

    // ---------------------------------------------------------------
    // Forfeiture
    // ---------------------------------------------------------------

    /// @dev Every `forfeitures` row on a contract with the row's forfeitBps: a bond whose
    /// principal is the row's eff_stake (planted in its record, with the contract holding at least
    /// that much) loses ceil(eff_stake * forfeitBps / 10,000), which is the row's penalty and goes
    /// to slashSink, and keeps the row's eff_stake_after. The first row's `Forfeited` log is the
    /// `governance_events` entry.
    function test_forfeitures_RoundingAndSink() external {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".forfeitures");
        assertEq(n, 7, "rows");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".forfeitures", i);
            uint256 balance = _uint(j, p, "eff_stake");
            uint256 bps = _uint(j, p, "forfeit_bps");
            uint256 penalty = _uint(j, p, "penalty");
            // ceil(balance * bps / 10,000) without the product overflowing.
            assertEq(
                penalty,
                (balance / 10_000) * bps + ((balance % 10_000) * bps + 9999) / 10_000,
                "rounded up"
            );
            assertEq(_uint(j, p, "eff_stake_after"), balance - penalty, "the rest stays");

            uint256 fresh = vm.snapshotState();
            IEtnaStaking.Config memory cfg = _config();
            cfg.forfeitBps = bps;
            staking = _deploy(cfg);
            uint256 bondId = _register(0xC0A, Alice, MIN_STAKE);
            bytes32 word2 = bytes32(uint256(keccak256(abi.encode(bondId, uint256(T) + 260))) + 2);
            vm.store(address(staking), word2, bytes32(balance));
            if (balance > MIN_STAKE) token.mint(address(staking), balance - MIN_STAKE);

            vm.recordLogs();
            vm.prank(STAKING_OWNER);
            staking.forfeit(bondId, _INCIDENT_ID, _VALID_UNTIL);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            assertEq(token.balanceOf(SLASH_SINK), penalty, "to slashSink");
            assertEq(staking.bondAt(bondId).effStake, balance - penalty, "effStake after");
            assertTrue(staking.forfeited(bondId), "flag");
            if (i == 0) {
                _assertLoggedEvent(j, "forfeited", logs, IEtnaStaking.Forfeited.selector);
            }
            vm.revertToState(fresh);
        }
    }

    // ---------------------------------------------------------------
    // ABI
    // ---------------------------------------------------------------

    /// @dev The `governance_abi`, `view_abi` and `governance_events` entries labelled `staking`
    /// match the Solidity selectors, calldata and declared events; every entry of the three
    /// families carries a label this suite or the L1 Inbox suite reads.
    function test_vectors_StakingSelectorsEventsMatchSolidityAbi() external {
        string memory j = LibEtnaVectors.load();
        _assertStakingLabels(j, ".governance_abi", 7);
        _assertStakingLabels(j, ".view_abi", 7);
        _assertStakingLabels(j, ".governance_events", 2);

        string memory g = ".governance_abi.";
        string memory reg = ".register_digests[0].";
        _assertCall(
            j,
            string.concat(g, "register"),
            IEtnaStaking.register.selector,
            abi.encodeCall(
                IEtnaStaking.register, (_bytes(j, reg, "key"), MIN_STAKE, _bytes(j, reg, "pop_sig"))
            )
        );
        _assertCall(
            j,
            string.concat(g, "top_up"),
            IEtnaStaking.topUp.selector,
            abi.encodeCall(IEtnaStaking.topUp, (0, 100))
        );
        _assertCall(
            j,
            string.concat(g, "request_exit"),
            IEtnaStaking.requestExit.selector,
            abi.encodeCall(IEtnaStaking.requestExit, (0))
        );
        _assertCall(
            j,
            string.concat(g, "withdraw"),
            IEtnaStaking.withdraw.selector,
            abi.encodeCall(IEtnaStaking.withdraw, (0, _OWNER_AA))
        );
        _assertCall(
            j,
            string.concat(g, "forfeit"),
            IEtnaStaking.forfeit.selector,
            abi.encodeCall(IEtnaStaking.forfeit, (0, _INCIDENT_ID, _VALID_UNTIL))
        );
        _assertCall(
            j,
            string.concat(g, "on_block_start"),
            IEtnaStaking.onBlockStart.selector,
            abi.encodeCall(IEtnaStaking.onBlockStart, (1, 5))
        );
        string[] memory names = _voteNames(j);
        _assertCall(
            j,
            string.concat(g, "slash_double_sign"),
            IEtnaStaking.slashDoubleSign.selector,
            abi.encodeCall(
                IEtnaStaking.slashDoubleSign,
                (
                    _uint(j, ".votes.slash_abi.", "bond_id"),
                    _vectorVote(j, names, _string(j, ".votes.slash_abi.", "a")),
                    _vectorVote(j, names, _string(j, ".votes.slash_abi.", "b"))
                )
            )
        );
        assertEq(
            _bytes(j, string.concat(g, "slash_double_sign."), "calldata"),
            _bytes(j, ".votes.slash_abi.", "calldata"),
            "the votes section's slash call"
        );

        string memory v = ".view_abi.";
        address a1 = _address(j, ".keys[0].", "ck_addr");
        _assertCall(
            j,
            string.concat(v, "bond_for_key"),
            IEtnaStaking.bondForKey.selector,
            abi.encodeCall(IEtnaStaking.bondForKey, (a1))
        );
        _assertCall(
            j,
            string.concat(v, "seat_of_bond"),
            IEtnaStaking.seatOfBond.selector,
            abi.encodeCall(IEtnaStaking.seatOfBond, (0))
        );
        _assertCall(
            j,
            string.concat(v, "bond_in_seat"),
            IEtnaStaking.bondInSeat.selector,
            abi.encodeCall(IEtnaStaking.bondInSeat, (0))
        );
        _assertCall(
            j,
            string.concat(v, "snapshot"),
            IEtnaStaking.snapshot.selector,
            abi.encodeCall(IEtnaStaking.snapshot, ())
        );
        _assertCall(
            j,
            string.concat(v, "register_digest"),
            IEtnaStaking.registerDigest.selector,
            abi.encodeCall(IEtnaStaking.registerDigest, (_OWNER_AA))
        );
        _assertCall(
            j,
            string.concat(v, "forfeited"),
            IEtnaStaking.forfeited.selector,
            abi.encodeCall(IEtnaStaking.forfeited, (0))
        );
        _assertCall(
            j,
            string.concat(v, "min_stake"),
            IEtnaStaking.minStake.selector,
            abi.encodeCall(IEtnaStaking.minStake, ())
        );

        vm.recordLogs();
        emit IEtnaStaking.TopUpDeposited(0, 100);
        emit IEtnaStaking.Forfeited(0, _INCIDENT_ID, 100, 10);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertLoggedEvent(j, "top_up_deposited", logs, IEtnaStaking.TopUpDeposited.selector);
        _assertLoggedEvent(j, "forfeited", logs, IEtnaStaking.Forfeited.selector);
    }

    /// @dev The staking views at the vector address return `view_abi`'s data: absence for an
    /// unused key, an unissued bond and an empty seat, the empty snapshot, the deployment's
    /// minStake and the owner 0xaa digest; once key a1 registers as bond 0 in seat 0, its lookups
    /// name bond 0 and seat 0, and once forfeited its flag is set. Separately, bonds of 10^14 in
    /// seat 0 (K1) and 2.5 * 10^14 in seat 2 (K2), seat 1 empty, give the two-seat snapshot at
    /// block 10.
    function test_views_ReturnTheVectorEncodings() external {
        string memory j = LibEtnaVectors.load();
        _etchVectorStaking(j);
        _assertViewResult(j, "bond_for_key", 1, "unused_key");
        _assertViewResult(j, "seat_of_bond", 1, "no_seat");
        _assertViewResult(j, "bond_in_seat", 1, "empty_seat");
        _assertViewResult(j, "snapshot", 1, "empty");
        _assertViewResult(j, "forfeited", 1, "not_forfeited");
        _assertViewResult(j, "min_stake", 0, "deployment");
        _assertViewResult(j, "register_digest", 0, "owner_aa");
        uint256 fresh = vm.snapshotState();

        string memory control = ".register_digests[0].";
        _fund(_OWNER_AA, MIN_STAKE);
        vm.prank(_OWNER_AA);
        staking.register(_bytes(j, control, "key"), MIN_STAKE, _bytes(j, control, "pop_sig"));
        _assertViewResult(j, "bond_for_key", 0, "bond_0");
        _assertViewResult(j, "seat_of_bond", 0, "seat_0");
        _assertViewResult(j, "bond_in_seat", 0, "bond_0");
        vm.prank(STAKING_OWNER);
        staking.forfeit(0, _INCIDENT_ID, block.timestamp);
        _assertViewResult(j, "forfeited", 0, "forfeited");
        vm.revertToState(fresh);

        _register(1, Bob, MIN_STAKE);
        _register(3, Bob, MIN_STAKE);
        _register(2, Bob, MIN_STAKE);
        _requestExit(1);
        _setEffStake(0, 100_000 * VP_UNIT);
        _setEffStake(2, 250_000 * VP_UNIT);
        vm.roll(10);
        vm.prank(SYSTEM_CALLER);
        staking.onBlockStart(0, 0);
        _assertViewResult(j, "snapshot", 0, "two_seats");
        IEtnaStaking.SeatMember[] memory members = new IEtnaStaking.SeatMember[](2);
        members[0] = IEtnaStaking.SeatMember({ seat: 0, ckPrefix: 2, ckX: _K1_X, power: 100_000 });
        members[1] = IEtnaStaking.SeatMember({ seat: 2, ckPrefix: 2, ckX: _K2_X, power: 250_000 });
        assertEq(
            abi.encode(uint256(10), uint256(350_000 * VP_UNIT), members),
            _bytes(j, ".view_abi.snapshot.", "results[0].data"),
            "two_seats values"
        );
    }

    // ---------------------------------------------------------------
    // Helpers: deployment
    // ---------------------------------------------------------------

    /// @dev Checks that the vector deployment is the base's reference configuration on this L2
    /// chain, then etches the staking implementation at `_VECTOR_IMPL` and an EIP-1967 proxy to it
    /// at the vector staking address, initializes the proxy to `STAKING_OWNER` and makes it
    /// `staking`. The token stays this suite's stand-in: no vector binds the token address.
    function _etchVectorStaking(string memory _j) private {
        string memory d = ".deployment.";
        assertEq(_uint(_j, d, "l2_chain_id"), block.chainid, "L2 chain");
        assertEq(_uint(_j, d, "l1_chain_id"), L1_CHAIN_ID, "L1 chain");
        assertEq(_address(_j, d, "inbox"), INBOX, "Inbox");
        assertEq(_uint(_j, d, "min_stake"), MIN_STAKE, "minStake");
        assertEq(_uint(_j, d, "vp_unit"), VP_UNIT, "vpUnit");
        assertEq(_uint(_j, d, "n_max"), N_MAX, "nMax");
        assertEq(_uint(_j, d, "miss_limit"), MISS_LIMIT, "missLimit");
        assertEq(_uint(_j, d, "miss_slash_bps"), MISS_SLASH_BPS, "missSlashBps");
        assertEq(_uint(_j, d, "slash_bounty_bps"), SLASH_BOUNTY_BPS, "slashBountyBps");
        assertEq(_uint(_j, d, "forfeit_bps"), FORFEIT_BPS, "forfeitBps");
        assertEq(_uint(_j, d, "withdrawal_delay"), WITHDRAWAL_DELAY, "withdrawalDelay");

        address at = _address(_j, d, "staking");
        EtnaStaking impl = new EtnaStaking(_config());
        vm.etch(_VECTOR_IMPL, address(impl).code);
        vm.etch(at, address(new ERC1967Proxy(address(impl), "")).code);
        vm.store(at, _IMPLEMENTATION_SLOT, bytes32(uint256(uint160(_VECTOR_IMPL))));
        EtnaStaking(at).init(STAKING_OWNER);
        staking = EtnaStaking(at);
        assertEq(staking.owner(), STAKING_OWNER, "owner");
    }

    /// @dev Plants `_effStake` as bond `_bondId`'s principal, word 2 of its record at
    /// keccak256(abi.encode(bondId, T + 260)).
    function _setEffStake(uint256 _bondId, uint256 _effStake) private {
        bytes32 slot = bytes32(uint256(keccak256(abi.encode(_bondId, uint256(T) + 260))) + 2);
        vm.store(address(staking), slot, bytes32(_effStake));
    }

    // ---------------------------------------------------------------
    // Helpers: layout
    // ---------------------------------------------------------------

    /// @dev Record s sits at T + 3 + 2s (ckX) and T + 4 + 2s (prefix and power).
    function _assertRecordSlots(string memory _j, string memory _s) private view {
        string memory records = string.concat(_s, "record_slots");
        uint256 n = LibEtnaVectors.lengthAt(_j, records);
        assertEq(n, 3, "record slot items");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(records, i);
            uint256 seat = _uint(_j, p, "seat");
            assertEq(uint256(_bytes32(_j, p, "word1")), uint256(T) + 3 + 2 * seat, "word 1");
            assertEq(uint256(_bytes32(_j, p, "word2")), uint256(T) + 4 + 2 * seat, "word 2");
        }
    }

    /// @dev Each key's word sits at keccak256(abi.encode(ckAddr, T + 2)). A word gives seat s only
    /// when holdsSeat (bits 0-7) is 1, seat (bits 8-15) is below 128 and every higher bit is 0;
    /// every other word gives no seat, which the file writes as null, never as 0.
    function _assertKeySeatWords(string memory _j, string memory _s) private view {
        string memory slots = string.concat(_s, "key_seat_slots");
        for (uint256 i; i < LibEtnaVectors.lengthAt(_j, slots); ++i) {
            string memory p = _at(slots, i);
            assertEq(
                _bytes32(_j, p, "slot"),
                keccak256(abi.encode(_address(_j, p, "ck_addr"), uint256(T) + 2)),
                "key-to-seat slot"
            );
        }

        string memory words = string.concat(_s, "key_seat_words");
        uint256 n = LibEtnaVectors.lengthAt(_j, words);
        assertEq(n, 8, "key-to-seat words");
        uint256 seatless;
        for (uint256 i; i < n; ++i) {
            string memory p = _at(words, i);
            uint256 word = uint256(_bytes32(_j, p, "word"));
            uint256 seat = (word >> 8) & 0xff;
            bool holdsSeat = (word & 0xff) == 1 && seat < 128 && (word >> 16) == 0;
            if (holdsSeat) {
                assertFalse(_isNull(_j, p, "seat"), "a seat");
                assertEq(_uint(_j, p, "seat"), seat, "the seat");
            } else {
                assertTrue(_isNull(_j, p, "seat"), "no seat is null");
                ++seatless;
            }
        }
        assertEq(seatless, 5, "seatless words");
        for (uint256 i; i < 2; ++i) {
            string memory p = _at(".packed_words.staking_key_seat", i);
            assertEq(
                uint256(_bytes32(_j, p, "word")),
                _uint(_j, p, "holds_seat") | (_uint(_j, p, "seat") << 8),
                "packed key-to-seat word"
            );
        }
    }

    /// @dev A record's second word packs ckPrefix (8 bits) then power (64 bits) from the
    /// least-significant bit, every higher bit zero.
    function _assertRecordWords(string memory _j, string memory _s) private pure {
        string memory rows = string.concat(_s, "record_word2");
        for (uint256 i; i < 2; ++i) {
            string memory p = _at(rows, i);
            string memory q = _at(".packed_words.staking_record_word2", i);
            uint256 word = uint256(_bytes32(_j, p, "word"));
            assertEq(word, _uint(_j, p, "ck_prefix") | (_uint(_j, p, "power") << 8), "packing");
            assertEq(word >> 72, 0, "bits from 72 up");
            assertLe(_uint(_j, p, "power"), type(uint64).max, "a 64-bit power");
            assertEq(bytes32(word), _bytes32(_j, q, "word"), "the packed-word item");
        }
    }

    // ---------------------------------------------------------------
    // Helpers: block-start cases
    // ---------------------------------------------------------------

    /// @dev Replays the `on_block_start` case at `_p` on a fresh staking contract.
    function _replayOnBlockStart(string memory _j, string memory _p) private {
        string memory name = _string(_j, _p, "name");
        staking = _deploy(_caseConfig(_j, _p, name));

        string memory call = string.concat(_p, "call.");
        uint256 blockNumber = _uint(_j, call, "block_number");
        string memory prior = string.concat(_p, "setup.prior_calls");
        uint256 priorCount = LibEtnaVectors.lengthAt(_j, prior);
        vm.roll(blockNumber - priorCount - 1);
        uint256 registered = _caseRegistrations(_j, _p, name);
        for (uint256 i; i < priorCount; ++i) {
            string memory c = _at(prior, i);
            vm.roll(blockNumber - priorCount + i);
            vm.prank(SYSTEM_CALLER);
            staking.onBlockStart(
                uint48(_uint(_j, c, "generation")), uint128(_uint(_j, c, "miss_bitmap"))
            );
        }
        assertEq(token.balanceOf(SLASH_SINK), 0, string.concat(name, ": no earlier penalty"));

        uint48 generation = uint48(_uint(_j, call, "generation"));
        bytes memory data = _bytes(_j, call, "calldata");
        assertEq(
            data,
            abi.encodeCall(
                IEtnaStaking.onBlockStart, (generation, uint128(_uint(_j, call, "miss_bitmap")))
            ),
            name
        );
        vm.roll(blockNumber);
        vm.prank(SYSTEM_CALLER);
        (bool ok,) = address(staking).call(data);
        assertTrue(ok, name);

        _assertCaseExpect(_j, _p, registered, name);
    }

    /// @dev The reference configuration with the case's overrides, each one of the five parameters
    /// of `on_block_start.deployment`.
    function _caseConfig(
        string memory _j,
        string memory _p,
        string memory _name
    )
        private
        view
        returns (IEtnaStaking.Config memory cfg_)
    {
        cfg_ = _config();
        string memory o = string.concat(_p, "overrides.");
        uint256 applied;
        if (vm.keyExistsJson(_j, string.concat(o, "n_max"))) {
            cfg_.nMax = _uint(_j, o, "n_max");
            ++applied;
        }
        if (vm.keyExistsJson(_j, string.concat(o, "min_stake"))) {
            cfg_.minStake = _uint(_j, o, "min_stake");
            ++applied;
        }
        if (vm.keyExistsJson(_j, string.concat(o, "vp_unit"))) {
            cfg_.vpUnit = _uint(_j, o, "vp_unit");
            ++applied;
        }
        if (vm.keyExistsJson(_j, string.concat(o, "miss_limit"))) {
            cfg_.missLimit = _uint(_j, o, "miss_limit");
            ++applied;
        }
        if (vm.keyExistsJson(_j, string.concat(o, "miss_slash_bps"))) {
            cfg_.missSlashBps = _uint(_j, o, "miss_slash_bps");
            ++applied;
        }
        assertEq(
            LibEtnaVectors.entryCount(_j, string.concat(_p, "overrides")),
            applied,
            string.concat(_name, ": every override is a deployment parameter")
        );
    }

    /// @dev Registers the case's bonds, bond i with the key of its private key and its amount,
    /// each taking its listed seat; returns their number.
    function _caseRegistrations(
        string memory _j,
        string memory _p,
        string memory _name
    )
        private
        returns (uint256 count_)
    {
        string memory list = string.concat(_p, "setup.registrations");
        count_ = LibEtnaVectors.lengthAt(_j, list);
        for (uint256 i; i < count_; ++i) {
            string memory r = _at(list, i);
            assertEq(_uint(_j, r, "bond_id"), i, _name);
            assertEq(_uint(_j, r, "private_key"), 0x100 + i, _name);
            uint256 bondId = _register(0x100 + i, Alice, _uint(_j, r, "amount"));
            assertEq(bondId, i, _name);
            _assertSeatOfBond(bondId, true, uint8(_uint(_j, r, "seat")), _name);
        }
    }

    /// @dev Compares the state the case's call left with its `expect`.
    function _assertCaseExpect(
        string memory _j,
        string memory _p,
        uint256 _registered,
        string memory _name
    )
        private
        view
    {
        string memory e = string.concat(_p, "expect.");
        _assertCaseMissCounts(_j, e, _name);
        _assertCaseBonds(_j, _p, e, _registered, _name);
        _assertCaseRecords(_j, e, _name);
        assertEq(token.balanceOf(SLASH_SINK), _uint(_j, e, "penalty_total"), _name);
        assertEq(
            uint256(vm.load(address(staking), bytes32(uint256(T) + 1))),
            _uint(_j, e, "snapshot_total_stake"),
            string.concat(_name, ": snapshotTotalStake")
        );
        assertEq(
            uint256(vm.load(address(staking), T)),
            _uint(_j, e, "snapshot_height"),
            string.concat(_name, ": snapshotHeight")
        );
        assertEq(_uint(_j, e, "snapshot_height"), block.number, _name);
        assertEq(staking.lastGeneration(), _uint(_j, e, "last_generation"), _name);
    }

    /// @dev Every seat's miss count: the listed ones, and zero for every other seat.
    function _assertCaseMissCounts(
        string memory _j,
        string memory _e,
        string memory _name
    )
        private
        view
    {
        uint256[128] memory expected;
        string memory list = string.concat(_e, "miss_counts");
        uint256 n = LibEtnaVectors.lengthAt(_j, list);
        for (uint256 i; i < n; ++i) {
            string memory m = _at(list, i);
            expected[_uint(_j, m, "seat")] = _uint(_j, m, "count");
        }
        for (uint256 s; s < 128; ++s) {
            assertEq(staking.missCount(uint8(s)), expected[s], string.concat(_name, ": miss count"));
        }
    }

    /// @dev Every bond's effStake, and its seat unless the call released it.
    function _assertCaseBonds(
        string memory _j,
        string memory _p,
        string memory _e,
        uint256 _registered,
        string memory _name
    )
        private
        view
    {
        string memory stakes = string.concat(_e, "eff_stakes");
        assertEq(LibEtnaVectors.lengthAt(_j, stakes), _registered, _name);
        for (uint256 i; i < _registered; ++i) {
            string memory b = _at(stakes, i);
            uint256 bondId = _uint(_j, b, "bond_id");
            assertEq(staking.bondAt(bondId).effStake, _uint(_j, b, "eff_stake"), _name);
        }

        bool[] memory released = new bool[](_registered);
        string memory list = string.concat(_e, "released");
        for (uint256 i; i < LibEtnaVectors.lengthAt(_j, list); ++i) {
            released[LibEtnaVectors.uintAt(_j, string.concat(list, "[", vm.toString(i), "]"))] =
            true;
        }
        string memory registrations = string.concat(_p, "setup.registrations");
        for (uint256 i; i < _registered; ++i) {
            uint8 seat = uint8(_uint(_j, _at(registrations, i), "seat"));
            if (released[i]) {
                _assertSeatOfBond(i, false, 0, string.concat(_name, ": released"));
                _assertBondInSeat(seat, false, 0, string.concat(_name, ": released"));
                assertEq(staking.bondAt(i).exitHeight, NO_EXIT, "no exit is set");
            } else {
                _assertSeatOfBond(i, true, seat, string.concat(_name, ": kept"));
            }
        }
    }

    /// @dev All 128 snapshot records: the listed ones, and zero for every other seat.
    function _assertCaseRecords(
        string memory _j,
        string memory _e,
        string memory _name
    )
        private
        view
    {
        bytes32[128] memory word1;
        bytes32[128] memory word2;
        string memory list = string.concat(_e, "records");
        uint256 n = LibEtnaVectors.lengthAt(_j, list);
        for (uint256 i; i < n; ++i) {
            string memory r = _at(list, i);
            uint256 seat = _uint(_j, r, "seat");
            word1[seat] = _bytes32(_j, r, "word1");
            word2[seat] = _bytes32(_j, r, "word2");
        }
        for (uint256 s; s < 128; ++s) {
            assertEq(
                vm.load(address(staking), bytes32(uint256(T) + 3 + 2 * s)),
                word1[s],
                string.concat(_name, ": record word 1")
            );
            assertEq(
                vm.load(address(staking), bytes32(uint256(T) + 4 + 2 * s)),
                word2[s],
                string.concat(_name, ": record word 2")
            );
        }
    }

    // ---------------------------------------------------------------
    // Helpers: votes
    // ---------------------------------------------------------------

    /// @dev Stores the pair's `current_generation` through a block-start call and submits its
    /// votes as Bob: a double-sign pair must slash the whole stake, any other must revert with the
    /// error of its reason. Returns whether the pair is a double sign.
    function _checkPair(
        string memory _j,
        string[] memory _names,
        string memory _p
    )
        private
        returns (bool slashed_)
    {
        string memory name = _string(_j, _p, "name");
        IEtnaStaking.Vote memory a = _vectorVote(_j, _names, _string(_j, _p, "a"));
        IEtnaStaking.Vote memory b = _vectorVote(_j, _names, _string(_j, _p, "b"));
        _blockStart(uint48(_uint(_j, _p, "current_generation")), 0);

        slashed_ = _bool(_j, _p, "double_sign");
        if (!slashed_) {
            vm.expectRevert(_errorFor(_string(_j, _p, "reason")));
            vm.prank(Bob);
            staking.slashDoubleSign(0, a, b);
            return false;
        }
        assertEq(_string(_j, _p, "reason"), "double_sign", name);
        vm.prank(Bob);
        staking.slashDoubleSign(0, a, b);
        assertEq(staking.bondAt(0).effStake, 0, name);
        uint256 bounty = MIN_STAKE * SLASH_BOUNTY_BPS / 10_000;
        assertEq(token.balanceOf(Bob), bounty, name);
        assertEq(token.balanceOf(SLASH_SINK), MIN_STAKE - bounty, name);
    }

    /// @dev The error a pair that is not a double sign reverts with, by its reason.
    function _errorFor(string memory _reason) private pure returns (bytes4) {
        bytes32 r = keccak256(bytes(_reason));
        if (
            r == keccak256("same_block_id") || r == keccak256("different_round")
                || r == keccak256("different_type") || r == keccak256("different_height")
                || r == keccak256("different_generation")
        ) return IEtnaStaking.NotDoubleSign.selector;
        if (r == keccak256("future_generation")) return IEtnaStaking.FutureGeneration.selector;
        if (r == keccak256("other_deployment")) return LibEtnaKeys.InvalidSignature.selector;
        revert(string.concat("unknown pair reason ", _reason));
    }

    /// @dev The names of the `votes.cases` items, in order.
    function _voteNames(string memory _j) private view returns (string[] memory names_) {
        names_ = new string[](LibEtnaVectors.lengthAt(_j, ".votes.cases"));
        for (uint256 i; i < names_.length; ++i) {
            names_[i] = _string(_j, _at(".votes.cases", i), "name");
        }
    }

    /// @dev The vote of the `votes.cases` item named `_name`, with its vector signature.
    function _vectorVote(
        string memory _j,
        string[] memory _names,
        string memory _name
    )
        private
        pure
        returns (IEtnaStaking.Vote memory v_)
    {
        uint256 i;
        while (i < _names.length && keccak256(bytes(_names[i])) != keccak256(bytes(_name))) {
            ++i;
        }
        require(i < _names.length, string.concat("no vote case named ", _name));
        string memory p = _at(".votes.cases", i);
        string memory q = string.concat(p, "vote.");
        v_.voteType = uint8(_uint(_j, q, "voteType"));
        v_.height = uint64(_uint(_j, q, "height"));
        v_.round = uint32(_uint(_j, q, "round"));
        v_.blockHash = _bytes(_j, q, "blockHash");
        v_.partsTotal = uint32(_uint(_j, q, "partsTotal"));
        v_.partsHash = _bytes(_j, q, "partsHash");
        // The staking contract takes the int64 seconds as their two's-complement pattern.
        v_.timestampSeconds = uint64(_uint(_j, q, "timestampSecondsU64"));
        v_.timestampNanos = uint32(_uint(_j, q, "timestampNanos"));
        v_.generation = uint48(_uint(_j, q, "generation"));
        v_.signature = _bytes(_j, p, "signature");
    }

    // ---------------------------------------------------------------
    // Helpers: ABI
    // ---------------------------------------------------------------

    /// @dev The family at `_family` has `_staking` entries labelled `staking`, and every entry is
    /// labelled `staking`, `inbox` or `unzen_inbox`.
    function _assertStakingLabels(
        string memory _j,
        string memory _family,
        uint256 _staking
    )
        private
        pure
    {
        uint256 stakingCount = LibEtnaVectors.countWithContract(_j, _family, "staking");
        assertEq(stakingCount, _staking, string.concat(_family, ": staking entries"));
        assertEq(
            stakingCount + LibEtnaVectors.countWithContract(_j, _family, "inbox")
                + LibEtnaVectors.countWithContract(_j, _family, "unzen_inbox"),
            LibEtnaVectors.entryCount(_j, _family),
            string.concat(_family, ": every entry names a known contract")
        );
    }

    /// @dev The staking call entry at `_p`: its signature hashes to its selector, which is
    /// Solidity's `_selector`, and its calldata is `_calldata`.
    function _assertCall(
        string memory _j,
        string memory _p,
        bytes4 _selector,
        bytes memory _calldata
    )
        private
        pure
    {
        assertEq(_string(_j, _p, ".contract"), "staking", _p);
        assertEq(_bytes(_j, _p, ".selector"), abi.encodePacked(_selector), _p);
        assertEq(bytes4(keccak256(bytes(_string(_j, _p, ".signature")))), _selector, _p);
        assertEq(_bytes(_j, _p, ".calldata"), _calldata, _p);
    }

    /// @dev The staking view `view_abi.<_name>` returns the data of its result `_index`, named
    /// `_result`.
    function _assertViewResult(
        string memory _j,
        string memory _name,
        uint256 _index,
        string memory _result
    )
        private
        view
    {
        string memory v = string.concat(".view_abi.", _name, ".");
        string memory r = string.concat(v, "results[", vm.toString(_index), "].");
        assertEq(_string(_j, r, "name"), _result, _name);
        (bool ok, bytes memory data) = address(staking).staticcall(_bytes(_j, v, "calldata"));
        assertTrue(ok, _name);
        assertEq(data, _bytes(_j, r, "data"), string.concat(_name, ": ", _result));
    }

    /// @dev The log of `_logs` with topic0 `_topic0` is the staking `governance_events` entry
    /// `_name`, with its indexed topics and data.
    function _assertLoggedEvent(
        string memory _j,
        string memory _name,
        Vm.Log[] memory _logs,
        bytes32 _topic0
    )
        private
        view
    {
        string memory e = string.concat(".governance_events.", _name, ".");
        assertEq(_string(_j, e, "contract"), "staking", _name);
        assertEq(_bytes32(_j, e, "topic0"), _topic0, _name);
        assertEq(keccak256(bytes(_string(_j, e, "signature"))), _topic0, _name);
        uint256 i;
        while (i < _logs.length && _logs[i].topics[0] != _topic0) {
            ++i;
        }
        require(i < _logs.length, string.concat("no log of ", _name));
        Vm.Log memory log = _logs[i];
        uint256 indexedCount = LibEtnaVectors.lengthAt(_j, string.concat(e, "indexed_topics"));
        assertEq(log.topics.length, indexedCount + 1, _name);
        for (uint256 t; t < indexedCount; ++t) {
            assertEq(
                log.topics[t + 1],
                _bytes32(_j, e, string.concat("indexed_topics[", vm.toString(t), "]")),
                _name
            );
        }
        assertEq(log.data, _bytes(_j, e, "data"), _name);
    }

    /// @dev The big-endian integer of `_length` bytes of `_data` from `_offset`.
    function _bigEndian(
        bytes memory _data,
        uint256 _offset,
        uint256 _length
    )
        private
        pure
        returns (uint256 value_)
    {
        for (uint256 i; i < _length; ++i) {
            value_ = (value_ << 8) | uint8(_data[_offset + i]);
        }
    }
}
