// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryTestBase } from "./EtnaStakingRegistryTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { LibEtnaKeys } from "src/layer1/etna/libs/LibEtnaKeys.sol";

contract EtnaStakingRegistryTest is EtnaStakingRegistryTestBase {
    /// @dev Consensus private keys.
    uint256 private constant _CK_A = 0xC0A;
    uint256 private constant _CK_B = 0xC0B;
    uint256 private constant _CK_C = 0xC0C;
    uint256 private constant _CK_D = 0xC0D;
    uint256 private constant _CK_E = 0xC0E;
    uint256 private constant _CK_F = 0xC0F;
    /// @dev The first of the consensus private keys that fill the registry.
    uint256 private constant _CK_FILL = 0xF000;

    /// @dev The `exitEffectiveL1` of an entry with no exit set.
    uint48 private constant _NO_EXIT = type(uint48).max;

    // ---------------------------------------------------------------
    // constructor and init
    // ---------------------------------------------------------------

    function test_constructor_SetsImmutables() external view {
        assertEq(address(registry.token()), address(token), "token");
        assertEq(registry.minStake(), MIN_STAKE, "min stake");
        assertEq(registry.activationDelay(), ACTIVATION_DELAY, "activation delay");
        assertEq(registry.exitDelay(), EXIT_DELAY, "exit delay");
        assertEq(registry.withdrawalDelay(), WITHDRAWAL_DELAY, "withdrawal delay");
        assertEq(registry.slashBountyBps(), SLASH_BOUNTY_BPS, "slash bounty");
        assertEq(registry.slashSink(), SLASH_SINK, "slash sink");
        assertEq(registry.l2ChainId(), L2_CHAIN_ID, "l2 chain id");
        assertEq(registry.inbox(), address(mockInbox), "inbox");
        assertEq(registry.NO_EXIT(), 2 ** 48 - 1, "no-exit sentinel");
        assertEq(registry.MAX_ENTRIES(), 4096, "capacity");
    }

    function test_init_SetsTheOwnerOnce() external {
        assertEq(registry.owner(), address(this), "owner defaults to the caller");
        vm.expectRevert("Initializable: contract is already initialized");
        registry.init(Alice);
    }

    function test_constructor_RevertWhen_DelayOutOfRange() external {
        for (uint256 i; i < 3; ++i) {
            IEtnaStakingRegistry.Config memory cfg = _withDelay(i, 0);
            vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
            new EtnaStakingRegistry(cfg);

            cfg = _withDelay(i, 2 ** 32);
            vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
            new EtnaStakingRegistry(cfg);

            new EtnaStakingRegistry(_withDelay(i, 1));
            new EtnaStakingRegistry(_withDelay(i, 2 ** 32 - 1));
        }
    }

    function test_constructor_RevertWhen_BountyAboveTenThousand() external {
        IEtnaStakingRegistry.Config memory cfg = _config();
        cfg.slashBountyBps = 10_001;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg.slashBountyBps = 10_000;
        assertEq(new EtnaStakingRegistry(cfg).slashBountyBps(), 10_000);
        cfg.slashBountyBps = 0;
        assertEq(new EtnaStakingRegistry(cfg).slashBountyBps(), 0);
    }

    function test_constructor_RevertWhen_ZeroOrCodelessParameters() external {
        IEtnaStakingRegistry.Config memory cfg = _config();
        cfg.token = address(0);
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg = _config();
        cfg.minStake = 0;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg = _config();
        cfg.slashSink = address(0);
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg = _config();
        cfg.l2ChainId = 0;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg = _config();
        cfg.inbox = address(0);
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg.inbox = Alice;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);
    }

    // ---------------------------------------------------------------
    // views
    // ---------------------------------------------------------------

    function test_views_AreEmptyBeforeTheFirstRegistration() external {
        assertEq(registry.checkpointCount(), 0, "checkpoints");
        assertEq(registry.entryCount(), 0, "entries");
        assertEq(registry.entriesRoot(), bytes32(0), "root of no entry");
        assertEq(registry.freeSlotCount(), 0, "free slots");
        assertEq(registry.ownerOf(0), address(0), "owner");
        assertEq(registry.exitConfirmedAtL1(0), 0, "confirmation");
        assertFalse(registry.keyUsed(Alice), "key");

        vm.expectRevert(IEtnaStakingRegistry.UnknownCheckpoint.selector);
        registry.checkpointAt(0);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        registry.entryAt(0);
    }

    function test_registerDigest_IsEip712OverTheOwner() external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("EtnaStakingRegistry"),
                keccak256("1"),
                block.chainid,
                address(registry)
            )
        );
        bytes32 structHash = keccak256(abi.encode(keccak256("Register(address owner)"), Alice));
        bytes32 expected = keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash));
        assertEq(registry.registerDigest(Alice), expected, "digest");
        assertTrue(registry.registerDigest(Bob) != expected, "binds the owner");

        // The domain follows the current chain id rather than one cached at deployment.
        vm.chainId(block.chainid + 1);
        assertTrue(registry.registerDigest(Alice) != expected, "binds the chain id");
    }

    // ---------------------------------------------------------------
    // register
    // ---------------------------------------------------------------

    function test_register_StoresKeyStakeAndActivation() external {
        (uint8 prefix, bytes32 x) = _compressed(_CK_A);
        uint48 activeFrom = uint48(block.number + ACTIVATION_DELAY);
        IEtnaStakingRegistry.Entry memory expected = _entry(prefix, x, MIN_STAKE, activeFrom);
        bytes32 leaf = LibEntriesTree.leaf(0, expected);
        _fund(Alice, MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        address ckAddr = vm.addr(_CK_A);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.CheckpointWritten(0, uint48(block.number), 1, leaf);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.Registered(0, Alice, ckAddr, prefix, x, MIN_STAKE, activeFrom);
        vm.prank(Alice);
        assertEq(registry.register(publicKey, MIN_STAKE, pop), 0, "bond id");

        _assertEntry(0, expected);
        assertEq(registry.entryAt(0).exitEffectiveL1, 281_474_976_710_655, "no exit set");
        assertEq(registry.entryCount(), 1, "entry count");
        assertEq(registry.ownerOf(0), Alice, "owner");
        assertTrue(registry.keyUsed(vm.addr(_CK_A)), "key used");
        assertEq(registry.exitConfirmedAtL1(0), 0, "no confirmation");
        assertEq(registry.freeSlotCount(), 0, "free slots");
        assertEq(registry.checkpointCount(), 1, "checkpoints");
        _assertCheckpoint(0, block.number, 1, leaf);
        assertEq(registry.entriesRoot(), leaf, "the root of one entry is its leaf");
        assertEq(token.balanceOf(address(registry)), MIN_STAKE, "stake held");
        assertEq(token.balanceOf(Alice), 0, "stake pulled");
    }

    /// @dev The raw words at the vector's slots (spec appendix B) hold the registered entry and
    /// checkpoint, packed from the least-significant bit as the vector's example words are.
    function test_register_StorageWordsMatchVectorPacking() external {
        string memory j = LibEtnaVectors.load();
        _assertPackingFormulasMatchVectorWords(j);
        uint256 registeredAt = block.number;
        _register(Alice, _CK_A);
        (uint8 prefix, bytes32 x) = _compressed(_CK_A);

        string memory r = ".layout.registry.";
        assertEq(_load(j, r, "checkpoints_slot"), 1, "checkpoints.length at R");
        assertEq(_load(j, r, "entries_slot"), 1, "entries.length at R + 1");

        string memory e = ".layout.registry.entry_slots[0].";
        assertEq(LibEtnaVectors.uintAt(j, string.concat(e, "index")), 0, "entry index");
        assertEq(bytes32(_load(j, e, "slots[0]")), x, "ckX");
        assertEq(_load(j, e, "slots[1]"), MIN_STAKE, "effStake");
        assertEq(
            _load(j, e, "slots[2]"),
            uint256(prefix) | (registeredAt + ACTIVATION_DELAY) << 8 | uint256(_NO_EXIT) << 56,
            "ckPrefix | activeFromL1 << 8 | exitEffectiveL1 << 56"
        );

        string memory c = ".layout.registry.checkpoint_slots[0].";
        assertEq(LibEtnaVectors.uintAt(j, string.concat(c, "index")), 0, "checkpoint index");
        assertEq(_load(j, c, "slots[0]"), registeredAt | 1 << 48, "l1Block | count << 48");
        assertEq(bytes32(_load(j, c, "slots[1]")), registry.entriesRoot(), "entriesRoot");

        string memory o = ".layout.registry.owners.slots[0].";
        assertEq(LibEtnaVectors.uintAt(j, string.concat(o, "bond_id")), 0, "owner bond id");
        assertEq(_load(j, o, "slot"), uint160(Alice), "owner");
    }

    function test_register_RevertWhen_StakeBelowMinimum() external {
        _fund(Alice, MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        bytes4 stakeTooLow = IEtnaStakingRegistry.StakeTooLow.selector;

        _assertRegisterReverts(Alice, publicKey, MIN_STAKE - 1, pop, stakeTooLow, "min - 1");
        _assertRegisterReverts(Alice, publicKey, 0, pop, stakeTooLow, "zero");
        // The stake is checked before the key and the proof of possession.
        _assertRegisterReverts(Alice, hex"04", MIN_STAKE - 1, "", stakeTooLow, "checked first");
        assertEq(registry.entryCount(), 0, "no entry");

        vm.prank(Alice);
        assertEq(registry.register(publicKey, MIN_STAKE, pop), 0, "the minimum is enough");
    }

    function test_register_StakesTheWholeAmount() external {
        uint256 amount = MIN_STAKE * 5 / 2;
        _fund(Alice, amount);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        vm.prank(Alice);
        registry.register(publicKey, amount, pop);

        assertEq(registry.entryAt(0).effStake, amount, "effStake");
        assertEq(token.balanceOf(address(registry)), amount, "stake held");
        assertEq(token.balanceOf(Alice), 0, "stake pulled");
    }

    /// @dev Every invalid `key_decompression` vector case is rejected before anything is written.
    function test_register_RevertWhen_PublicKeyMalformed() external {
        string memory j = LibEtnaVectors.load();
        _fund(Alice, MIN_STAKE);
        // A valid proof of possession of another key: the key is rejected before the PoP check.
        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        bytes4 invalidPublicKey = IEtnaStakingRegistry.InvalidPublicKey.selector;
        uint256 n = LibEtnaVectors.lengthAt(j, ".key_decompression");
        uint256 rejected;
        for (uint256 i; i < n; ++i) {
            string memory p = string.concat(".key_decompression[", vm.toString(i), "].");
            if (vm.parseJsonBool(j, string.concat(p, "valid"))) continue;
            bytes memory publicKey = LibEtnaVectors.bytesAt(j, string.concat(p, "public_key"));
            string memory label = string.concat(
                LibEtnaVectors.stringAt(j, string.concat(p, "name")),
                " (",
                LibEtnaVectors.stringAt(j, string.concat(p, "reason")),
                ")"
            );
            _assertRegisterReverts(Alice, publicKey, MIN_STAKE, pop, invalidPublicKey, label);
            ++rejected;
        }
        assertEq(rejected, 15, "rejection count");
        _assertRegisterReverts(Alice, hex"02", MIN_STAKE, "", invalidPublicKey, "before the PoP");

        assertEq(registry.entryCount(), 0, "no entry");
        assertEq(registry.checkpointCount(), 0, "no checkpoint");
    }

    /// @dev Freshly signed proofs of possession that are malformed, out of range or bound to
    /// another owner, key, chain or registry are rejected; the vector cases are checked at the
    /// vector registry in `EtnaVectors.t.sol`.
    function test_register_RevertWhen_PopInvalid() external {
        _fund(Alice, MIN_STAKE);
        _fund(Bob, MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes32 digest = registry.registerDigest(Alice);
        bytes memory pop = EtnaTestKeys.sig65(_CK_A, digest);
        (bytes32 r, bytes32 s, uint8 v) = _split(pop);
        uint256 n = LibEtnaKeys.N;

        // Bob submits Alice's calldata: the digest names the caller, so the owner cannot change.
        _assertPopRejected(Bob, publicKey, pop, "copied transaction");
        _assertPopRejected(
            Alice, publicKey, EtnaTestKeys.popSig(_CK_A, registry, Carol), "wrong owner"
        );
        _assertPopRejected(Alice, publicKey, EtnaTestKeys.sig65(_CK_B, digest), "wrong key");
        bytes32 otherChainDigest = _digestOnChain(block.chainid + 1);
        _assertPopRejected(
            Alice, publicKey, EtnaTestKeys.sig65(_CK_A, otherChainDigest), "wrong chain"
        );
        EtnaStakingRegistry other = _deployRegistry(address(mockInbox));
        _assertPopRejected(
            Alice, publicKey, EtnaTestKeys.popSig(_CK_A, other, Alice), "wrong registry"
        );

        _assertPopRejected(Alice, publicKey, abi.encodePacked(r, s, v + 27), "v + 27");
        _assertPopRejected(Alice, publicKey, abi.encodePacked(r, s, uint8(2)), "v = 2");
        // The high-s twin recovers the same address; only the range check rejects it.
        bytes memory highS = abi.encodePacked(r, bytes32(n - uint256(s)), v ^ 1);
        assertEq(ecrecover(digest, (v ^ 1) + 27, r, bytes32(n - uint256(s))), vm.addr(_CK_A));
        _assertPopRejected(Alice, publicKey, highS, "high s");
        _assertPopRejected(Alice, publicKey, abi.encodePacked(bytes32(0), s, v), "r = 0");
        _assertPopRejected(Alice, publicKey, abi.encodePacked(r, bytes32(0), v), "s = 0");
        _assertPopRejected(Alice, publicKey, abi.encodePacked(bytes32(n), s, v), "r = n");
        _assertPopRejected(
            Alice, publicKey, abi.encodePacked(bytes32(uint256(5)), s, v), "unrecoverable r"
        );
        _assertPopRejected(Alice, publicKey, abi.encodePacked(r, s), "64 bytes");
        _assertPopRejected(Alice, publicKey, abi.encodePacked(pop, uint8(0)), "66 bytes");
        assertEq(registry.entryCount(), 0, "no entry");

        // The valid proof of possession still registers the key: no rejection consumed it.
        vm.prank(Alice);
        registry.register(publicKey, MIN_STAKE, pop);
        assertEq(registry.ownerOf(0), Alice, "owner");
    }

    /// @dev The other prefix encodes the negated point (x, p - y), a valid key whose private key
    /// is n - pk. A PoP by pk does not match it; the negated key's own PoP registers it, under
    /// its own address.
    function test_register_RevertWhen_ParityFlippedKeyHasNoMatchingPop() external {
        (uint8 prefix, bytes32 x) = _compressed(_CK_A);
        bytes memory flipped = abi.encodePacked(prefix ^ 1, x);
        _fund(Alice, MIN_STAKE);
        _assertPopRejected(
            Alice, flipped, EtnaTestKeys.popSig(_CK_A, registry, Alice), "PoP of the other point"
        );

        uint256 negated = LibEtnaKeys.N - _CK_A;
        assertEq(EtnaTestKeys.publicKey(negated), flipped, "the negated key");
        bytes memory pop = EtnaTestKeys.popSig(negated, registry, Alice);
        vm.prank(Alice);
        registry.register(flipped, MIN_STAKE, pop);
        assertEq(registry.entryAt(0).ckPrefix, prefix ^ 1, "prefix");
        assertEq(registry.entryAt(0).ckX, x, "x");
        assertTrue(registry.keyUsed(vm.addr(negated)), "negated key used");
        assertFalse(registry.keyUsed(vm.addr(_CK_A)), "original key unused");
    }

    function test_register_RevertWhen_KeyAlreadyRegistered() external {
        _register(Alice, _CK_A);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes4 keyAlreadyUsed = IEtnaStakingRegistry.KeyAlreadyUsed.selector;
        _fund(Alice, MIN_STAKE);
        _fund(Bob, MIN_STAKE);

        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Bob);
        _assertRegisterReverts(Bob, publicKey, MIN_STAKE, pop, keyAlreadyUsed, "another owner");
        pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        _assertRegisterReverts(Alice, publicKey, MIN_STAKE, pop, keyAlreadyUsed, "same owner");
        // The proof of possession is checked before the key's use.
        _assertPopRejected(Bob, publicKey, pop, "PoP checked first");
        assertEq(registry.entryCount(), 1, "entry count");
    }

    /// @dev Changes within one L1 block overwrite its checkpoint; a later block appends one.
    function test_register_OneCheckpointPerL1Block() external {
        uint256 first = block.number;
        bytes32 leaf0 = _leafOf(0, _CK_A, first);
        _registerExpecting(Alice, _CK_A, 0, 0, leaf0);
        _assertCheckpoint(0, first, 1, leaf0);

        bytes32 rootOfTwo = keccak256(abi.encodePacked(leaf0, _leafOf(1, _CK_B, first)));
        _registerExpecting(Bob, _CK_B, 1, 0, rootOfTwo);
        assertEq(registry.checkpointCount(), 1, "one checkpoint for the block");
        _assertCheckpoint(0, first, 2, rootOfTwo);
        vm.expectRevert(IEtnaStakingRegistry.UnknownCheckpoint.selector);
        registry.checkpointAt(1);

        vm.roll(first + 1);
        bytes32 root = keccak256(
            abi.encodePacked(
                rootOfTwo, keccak256(abi.encodePacked(_leafOf(2, _CK_C, first + 1), bytes32(0)))
            )
        );
        _registerExpecting(Carol, _CK_C, 2, 1, root);
        assertEq(registry.checkpointCount(), 2, "the next block appends");
        _assertCheckpoint(0, first, 2, rootOfTwo);
        _assertCheckpoint(1, first + 1, 3, root);
        assertEq(registry.entriesRoot(), root, "root");
    }

    function test_register_RevertWhen_RegistryFull() external {
        uint256 capacity = registry.MAX_ENTRIES();
        vm.pauseGasMetering();
        _fund(Alice, (capacity + 1) * MIN_STAKE);
        for (uint256 i; i < capacity; ++i) {
            assertEq(_callRegister(Alice, _CK_FILL + i), i);
        }
        vm.resumeGasMetering();
        assertEq(registry.entryCount(), capacity, "entry count");
        assertEq(registry.checkpointCount(), 1, "checkpoints");
        _assertCheckpoint(0, block.number, capacity, registry.entriesRoot());

        uint256 pk = _CK_FILL + capacity;
        bytes memory publicKey = EtnaTestKeys.publicKey(pk);
        bytes memory pop = EtnaTestKeys.popSig(pk, registry, Alice);
        _assertRegisterReverts(
            Alice, publicKey, MIN_STAKE, pop, IEtnaStakingRegistry.RegistryFull.selector, "full"
        );
        assertFalse(registry.keyUsed(vm.addr(pk)), "key unused");

        // A used key is rejected as such before the capacity is checked.
        publicKey = EtnaTestKeys.publicKey(_CK_FILL);
        pop = EtnaTestKeys.popSig(_CK_FILL, registry, Alice);
        _assertRegisterReverts(
            Alice,
            publicKey,
            MIN_STAKE,
            pop,
            IEtnaStakingRegistry.KeyAlreadyUsed.selector,
            "key checked first"
        );
    }

    /// @dev Released slots are reused before new ones are appended, the most recently released
    /// first. The releases are planted in storage: the slot's entry and owner are zeroed and its
    /// bond id is pushed onto the free list.
    function test_register_ReusesFreeSlotsLastInFirstOut() external {
        _register(Alice, _CK_A);
        _register(Alice, _CK_B);
        _register(Alice, _CK_C);
        _plantRelease(0);
        _plantRelease(2);
        assertEq(registry.freeSlotCount(), 2, "free slots");

        vm.roll(block.number + 1);
        assertEq(_register(Bob, _CK_D), 2, "most recently released first");
        assertEq(registry.entryCount(), 3, "no slot appended");
        assertEq(_register(Bob, _CK_E), 0, "then the earlier release");
        assertEq(registry.freeSlotCount(), 0, "free list empty");
        assertEq(_register(Bob, _CK_F), 3, "then a new slot");
        assertEq(registry.entryCount(), 4, "entry count");

        assertEq(registry.ownerOf(0), Bob, "owner 0");
        assertEq(registry.ownerOf(1), Alice, "owner 1");
        assertEq(registry.ownerOf(2), Bob, "owner 2");
        assertEq(registry.entryAt(2).ckX, _xOf(_CK_D), "entry 2");
        assertEq(registry.entryAt(0).ckX, _xOf(_CK_E), "entry 0");
        bytes32 root = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked(_leafAt(0), _leafAt(1))),
                keccak256(abi.encodePacked(_leafAt(2), _leafAt(3)))
            )
        );
        assertEq(registry.entriesRoot(), root, "root over the current entries");
        _assertCheckpoint(1, block.number, 4, root);
    }

    function test_register_SucceedsBeforeInboxInitialization() external {
        // The deployment order: the registry is fixed to an Inbox proxy still on its bootstrap
        // implementation.
        address inboxProxy = address(
            new ERC1967Proxy(
                address(new EtnaInboxBootstrap()),
                abi.encodeCall(EtnaInboxBootstrap.init, (address(this)))
            )
        );
        assertFalse(EtnaInboxBootstrap(inboxProxy).isInitialized(), "not initialized");
        registry = _deployRegistry(inboxProxy);

        assertEq(_register(Alice, _CK_A), 0, "bond id");
        assertEq(registry.ownerOf(0), Alice, "owner");
        assertEq(registry.checkpointCount(), 1, "checkpoint");
    }

    /// @dev `activeFromL1` must be below the no-exit sentinel 2^48 - 1.
    function test_register_RevertWhen_ActivationOverflows48Bits() external {
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        bytes4 invalidEventBlock = IEtnaStakingRegistry.InvalidEventBlock.selector;
        _fund(Alice, MIN_STAKE);

        vm.roll(2 ** 48 - ACTIVATION_DELAY);
        _assertRegisterReverts(Alice, publicKey, MIN_STAKE, pop, invalidEventBlock, "2^48");
        vm.roll(2 ** 48 - 1 - ACTIVATION_DELAY);
        _assertRegisterReverts(Alice, publicKey, MIN_STAKE, pop, invalidEventBlock, "sentinel");
        assertEq(registry.checkpointCount(), 0, "no checkpoint");

        uint256 registeredAt = 2 ** 48 - 2 - ACTIVATION_DELAY;
        vm.roll(registeredAt);
        vm.prank(Alice);
        registry.register(publicKey, MIN_STAKE, pop);
        assertEq(registry.entryAt(0).activeFromL1, 2 ** 48 - 2, "activeFromL1");
        _assertCheckpoint(0, registeredAt, 1, registry.entriesRoot());
    }

    /// @dev The compressed key of any private key registers with its PoP, and the entry holds
    /// that key.
    function testFuzz_register_AcceptsAnyCreatedWallet(uint256 _pk) external {
        _pk = bound(_pk, 1, LibEtnaKeys.N - 1);
        Vm.Wallet memory wallet = vm.createWallet(_pk);
        uint8 prefix = uint8(2 + (wallet.publicKeyY & 1));
        bytes memory publicKey = abi.encodePacked(prefix, bytes32(wallet.publicKeyX));
        _fund(Alice, MIN_STAKE);
        bytes memory pop = EtnaTestKeys.sig65(_pk, registry.registerDigest(Alice));

        vm.prank(Alice);
        uint256 bondId = registry.register(publicKey, MIN_STAKE, pop);
        assertEq(registry.entryAt(bondId).ckPrefix, prefix, "prefix");
        assertEq(uint256(registry.entryAt(bondId).ckX), wallet.publicKeyX, "x");
        assertTrue(registry.keyUsed(wallet.addr), "key used");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _config() private view returns (IEtnaStakingRegistry.Config memory) {
        return _registryConfig(address(token), address(mockInbox));
    }

    /// @dev Returns the default config with delay `_which` (0 activation, 1 exit, 2 withdrawal)
    /// set to `_delay`.
    function _withDelay(
        uint256 _which,
        uint256 _delay
    )
        private
        view
        returns (IEtnaStakingRegistry.Config memory cfg_)
    {
        cfg_ = _config();
        if (_which == 0) cfg_.activationDelay = _delay;
        else if (_which == 1) cfg_.exitDelay = _delay;
        else cfg_.withdrawalDelay = _delay;
    }

    /// @dev `_staker` registers `_pk`'s key with `MIN_STAKE` as bond `_bondId`, which must emit
    /// checkpoint `_index` of the current block over `_bondId + 1` slots with root `_root`, then
    /// `Registered`.
    function _registerExpecting(
        address _staker,
        uint256 _pk,
        uint256 _bondId,
        uint256 _index,
        bytes32 _root
    )
        private
    {
        _fund(_staker, MIN_STAKE);
        (uint8 prefix, bytes32 x) = _compressed(_pk);
        bytes memory publicKey = EtnaTestKeys.publicKey(_pk);
        bytes memory pop = EtnaTestKeys.popSig(_pk, registry, _staker);
        address ckAddr = vm.addr(_pk);
        uint48 l1Block = uint48(block.number);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.CheckpointWritten(_index, l1Block, uint48(_bondId + 1), _root);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.Registered(
            _bondId, _staker, ckAddr, prefix, x, MIN_STAKE, l1Block + uint48(ACTIVATION_DELAY)
        );
        vm.prank(_staker);
        assertEq(registry.register(publicKey, MIN_STAKE, pop), _bondId, "bond id");
    }

    /// @dev `_staker` registers `_pk`'s key with `MIN_STAKE`.
    function _callRegister(address _staker, uint256 _pk) private returns (uint256) {
        bytes memory publicKey = EtnaTestKeys.publicKey(_pk);
        bytes memory pop = EtnaTestKeys.popSig(_pk, registry, _staker);
        vm.prank(_staker);
        return registry.register(publicKey, MIN_STAKE, pop);
    }

    function _assertPopRejected(
        address _caller,
        bytes memory _publicKey,
        bytes memory _pop,
        string memory _label
    )
        private
    {
        _assertRegisterReverts(
            _caller,
            _publicKey,
            MIN_STAKE,
            _pop,
            IEtnaStakingRegistry.InvalidSignature.selector,
            _label
        );
    }

    function _assertRegisterReverts(
        address _caller,
        bytes memory _publicKey,
        uint256 _amount,
        bytes memory _pop,
        bytes4 _error,
        string memory _label
    )
        private
    {
        vm.prank(_caller);
        try registry.register(_publicKey, _amount, _pop) returns (uint256 bondId) {
            assertTrue(false, string.concat(_label, ": registered bond ", vm.toString(bondId)));
        } catch (bytes memory err) {
            assertEq(err, abi.encodeWithSelector(_error), _label);
        }
    }

    /// @dev The registration digest of `Alice` at the registry, computed under `_chainId`.
    function _digestOnChain(uint256 _chainId) private returns (bytes32 digest_) {
        uint256 chainId = block.chainid;
        vm.chainId(_chainId);
        digest_ = registry.registerDigest(Alice);
        vm.chainId(chainId);
    }

    function _assertEntry(
        uint256 _bondId,
        IEtnaStakingRegistry.Entry memory _expected
    )
        private
        view
    {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_bondId);
        assertEq(entry.ckX, _expected.ckX, "ckX");
        assertEq(entry.effStake, _expected.effStake, "effStake");
        assertEq(entry.ckPrefix, _expected.ckPrefix, "ckPrefix");
        assertEq(entry.activeFromL1, _expected.activeFromL1, "activeFromL1");
        assertEq(entry.exitEffectiveL1, _expected.exitEffectiveL1, "exitEffectiveL1");
    }

    function _assertCheckpoint(
        uint256 _index,
        uint256 _l1Block,
        uint256 _count,
        bytes32 _root
    )
        private
        view
    {
        IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(_index);
        assertEq(checkpoint.l1Block, _l1Block, "checkpoint l1Block");
        assertEq(checkpoint.count, _count, "checkpoint count");
        assertEq(checkpoint.entriesRoot, _root, "checkpoint entriesRoot");
    }

    /// @dev An entry with no exit set.
    function _entry(
        uint8 _prefix,
        bytes32 _x,
        uint256 _stake,
        uint48 _activeFrom
    )
        private
        pure
        returns (IEtnaStakingRegistry.Entry memory)
    {
        return IEtnaStakingRegistry.Entry({
            ckX: _x,
            effStake: _stake,
            ckPrefix: _prefix,
            activeFromL1: _activeFrom,
            exitEffectiveL1: _NO_EXIT
        });
    }

    /// @dev The leaf of slot `_bondId` holding `_pk`'s key, registered with `MIN_STAKE` at
    /// `_l1Block`.
    function _leafOf(uint256 _bondId, uint256 _pk, uint256 _l1Block) private returns (bytes32) {
        (uint8 prefix, bytes32 x) = _compressed(_pk);
        return LibEntriesTree.leaf(
            _bondId, _entry(prefix, x, MIN_STAKE, uint48(_l1Block + ACTIVATION_DELAY))
        );
    }

    /// @dev The leaf of the entry the registry holds at `_bondId`.
    function _leafAt(uint256 _bondId) private view returns (bytes32) {
        return LibEntriesTree.leaf(_bondId, registry.entryAt(_bondId));
    }

    /// @dev The SEC1 prefix and X coordinate of `_pk`'s public key.
    function _compressed(uint256 _pk) private returns (uint8 prefix_, bytes32 x_) {
        Vm.Wallet memory wallet = vm.createWallet(_pk);
        prefix_ = uint8(2 + (wallet.publicKeyY & 1));
        x_ = bytes32(wallet.publicKeyX);
    }

    function _xOf(uint256 _pk) private returns (bytes32 x_) {
        (, x_) = _compressed(_pk);
    }

    /// @dev Splits a 65-byte signature `R ‖ S ‖ V`.
    function _split(bytes memory _sig) private pure returns (bytes32 r_, bytes32 s_, uint8 v_) {
        assembly {
            r_ := mload(add(_sig, 0x20))
            s_ := mload(add(_sig, 0x40))
            v_ := byte(0, mload(add(_sig, 0x60)))
        }
    }

    /// @dev The registry word at the vector slot `_p` + `_field`.
    function _load(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        view
        returns (uint256)
    {
        bytes32 slot = LibEtnaVectors.bytes32At(_j, string.concat(_p, _field));
        return uint256(vm.load(address(registry), slot));
    }

    /// @dev Each vector example word equals the packing formula over its fields.
    function _assertPackingFormulasMatchVectorWords(string memory _j) private pure {
        for (uint256 k; k < 2; ++k) {
            string memory w =
                string.concat(".packed_words.registry_entry_word3[", vm.toString(k), "].");
            assertEq(
                LibEtnaVectors.uintAt(_j, string.concat(w, "ck_prefix"))
                    | LibEtnaVectors.uintAt(_j, string.concat(w, "active_from_l1")) << 8
                    | LibEtnaVectors.uintAt(_j, string.concat(w, "exit_effective_l1")) << 56,
                uint256(LibEtnaVectors.bytes32At(_j, string.concat(w, "word"))),
                "entry word 3 formula"
            );
            w = string.concat(".packed_words.registry_checkpoint_word1[", vm.toString(k), "].");
            assertEq(
                LibEtnaVectors.uintAt(_j, string.concat(w, "l1_block"))
                    | LibEtnaVectors.uintAt(_j, string.concat(w, "count")) << 48,
                uint256(LibEtnaVectors.bytes32At(_j, string.concat(w, "word"))),
                "checkpoint word 1 formula"
            );
        }
    }

    /// @dev Plants the release of slot `_bondId`: zeroes its entry (three words at
    /// `keccak256(R + 1) + 3 * bondId`) and owner, and pushes it onto the free list (`freeSlots`,
    /// length at R + 3, elements from `keccak256(R + 3)`).
    function _plantRelease(uint256 _bondId) private {
        string memory j = LibEtnaVectors.load();
        uint256 base = uint256(LibEtnaVectors.bytes32At(j, ".layout.registry.base"));
        uint256 entry = uint256(keccak256(abi.encode(base + 1))) + 3 * _bondId;
        for (uint256 w; w < 3; ++w) {
            vm.store(address(registry), bytes32(entry + w), 0);
        }
        bytes32 owners = LibEtnaVectors.bytes32At(j, ".layout.registry.owners.base");
        vm.store(address(registry), keccak256(abi.encode(_bondId, owners)), 0);

        bytes32 lengthSlot = bytes32(base + 3);
        uint256 length = uint256(vm.load(address(registry), lengthSlot));
        bytes32 element = bytes32(uint256(keccak256(abi.encode(lengthSlot))) + length);
        vm.store(address(registry), element, bytes32(_bondId));
        vm.store(address(registry), lengthSlot, bytes32(length + 1));
    }
}
