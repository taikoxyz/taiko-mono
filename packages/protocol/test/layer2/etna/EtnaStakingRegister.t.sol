// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { EtnaVoteKeys } from "./EtnaVoteKeys.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { EtnaStaking } from "src/layer2/etna/EtnaStaking.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { LibEtnaKeys } from "src/shared/etna/LibEtnaKeys.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";
import { LibEtnaVectors } from "test/shared/etna/LibEtnaVectors.sol";

contract EtnaStakingRegisterTest is EtnaStakingTestBase {
    /// @dev Consensus private keys: K_i is the key of private key i.
    uint256 private constant _K1 = 1;
    uint256 private constant _K2 = 2;
    uint256 private constant _K3 = 3;
    uint256 private constant _K4 = 4;
    uint256 private constant _K5 = 5;
    uint256 private constant _CK_A = 0xC0A;
    uint256 private constant _CK_B = 0xC0B;

    // ---------------------------------------------------------------
    // register
    // ---------------------------------------------------------------

    function test_register_TakesLowestEmptySeatInTheSameCall() external {
        assertEq(_register(_K1, Bob, MIN_STAKE), 0, "the first bond id");

        _assertSeatOfBond(0, true, 0, "bond 0");
        _assertBondInSeat(0, true, 0, "seat 0");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K1)), bytes32(uint256(0x0001)), "key-to-seat");
        _assertBondForKey(EtnaTestKeys.ckAddr(_K1), true, 0, "key of bond 0");
        IEtnaStaking.Bond memory bond = staking.bondAt(0);
        assertTrue(bond.holdsSeat, "record holds the seat");
        assertEq(bond.seat, 0, "record seat");
        assertEq(staking.missCount(0), 0, "miss count");
    }

    function test_register_RecordsOwnerKeyStakeAndNoExit() external {
        uint256 amount = MIN_STAKE * 5 / 2;
        (uint8 prefix, bytes32 x) = EtnaTestKeys.fallbackKey(_K1);
        address ckAddr = EtnaTestKeys.ckAddr(_K1);
        _fund(Bob, amount);
        bytes memory publicKey = EtnaTestKeys.publicKey(_K1);
        bytes memory pop = EtnaVoteKeys.popSig(_K1, staking, Bob);

        vm.expectEmit(address(staking));
        emit IEtnaStaking.Registered(0, Bob, ckAddr, prefix, x, amount, 0);
        vm.prank(Bob);
        assertEq(staking.register(publicKey, amount, pop), 0, "bond id");

        IEtnaStaking.Bond memory bond = staking.bondAt(0);
        assertEq(bond.owner, Bob, "owner is the caller");
        assertEq(bond.ckPrefix, prefix, "prefix");
        assertEq(bond.ckX, x, "x");
        assertEq(bond.effStake, amount, "effStake");
        assertEq(bond.exitHeight, 2 ** 48 - 1, "no exit set");
        assertFalse(bond.withdrawn, "not withdrawn");
        assertEq(token.balanceOf(address(staking)), amount, "stake held");
        assertEq(token.balanceOf(Bob), 0, "stake pulled");
        assertEq(staking.bondCount(), 1, "bond count");
    }

    function test_register_IdsCountUpFrom0() external {
        assertEq(_register(_K1, Bob, MIN_STAKE), 0, "first");
        assertEq(_register(_K2, Bob, MIN_STAKE), 1, "second");
        assertEq(_register(_K3, Carol, MIN_STAKE), 2, "third");
        assertEq(staking.bondCount(), 3, "bond count");
        for (uint8 seat; seat < 3; ++seat) {
            _assertBondInSeat(seat, true, seat, "seat of each id");
        }
    }

    function test_register_RevertWhen_AmountBelowMinStake() external {
        _fund(Bob, MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_K1);
        bytes memory pop = EtnaVoteKeys.popSig(_K1, staking, Bob);
        bytes4 stakeTooLow = IEtnaStaking.StakeTooLow.selector;

        _assertRegisterReverts(Bob, publicKey, MIN_STAKE - 1, pop, stakeTooLow, "min - 1");
        _assertRegisterReverts(Bob, publicKey, 0, pop, stakeTooLow, "zero");
        // The stake is checked before the key and the proof of possession.
        _assertRegisterReverts(Bob, hex"04", MIN_STAKE - 1, "", stakeTooLow, "checked first");
        assertEq(staking.bondCount(), 0, "no bond issued");

        vm.prank(Bob);
        assertEq(staking.register(publicKey, MIN_STAKE, pop), 0, "the minimum is enough");
    }

    function test_register_RevertWhen_KeyUsedBefore() external {
        _register(_K1, Bob, MIN_STAKE);
        uint256 bondId = _register(_K2, Carol, MIN_STAKE);
        bytes4 keyAlreadyUsed = IEtnaStaking.KeyAlreadyUsed.selector;
        _fund(David, 3 * MIN_STAKE);
        bytes memory k2 = EtnaTestKeys.publicKey(_K2);
        bytes memory pop = EtnaVoteKeys.popSig(_K2, staking, David);

        _assertRegisterReverts(David, k2, MIN_STAKE, pop, keyAlreadyUsed, "while unwithdrawn");

        _requestExit(bondId);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(Carol);
        staking.withdraw(bondId, Carol);
        _assertRegisterReverts(David, k2, MIN_STAKE, pop, keyAlreadyUsed, "after withdrawal");

        // Bond 0's key is registered too: id 0 is not absence.
        _assertRegisterReverts(
            David,
            EtnaTestKeys.publicKey(_K1),
            MIN_STAKE,
            EtnaVoteKeys.popSig(_K1, staking, David),
            keyAlreadyUsed,
            "bond 0's key"
        );
        assertEq(staking.bondCount(), 2, "no bond issued");
        _assertBondForKey(EtnaTestKeys.ckAddr(_K2), true, bondId, "the key keeps its bond");
    }

    /// @dev With every seat held a registration reverts `NoEmptySeat` and moves no bond. The stake
    /// and the key are checked before the seat.
    function test_register_RevertWhen_EverySeatHeld() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.nMax = 4;
        cfg.minStake = 2.5e26;
        staking = _deploy(cfg);
        for (uint256 pk = _K1; pk <= _K4; ++pk) {
            _register(pk, Bob, cfg.minStake);
        }
        _assertBondInSeat(4, false, 0, "seat nMax does not exist");

        _fund(Carol, 2 * cfg.minStake);
        bytes memory publicKey = EtnaTestKeys.publicKey(_K5);
        bytes memory pop = EtnaVoteKeys.popSig(_K5, staking, Carol);
        bytes4 noEmptySeat = IEtnaStaking.NoEmptySeat.selector;
        _assertRegisterReverts(Carol, publicKey, cfg.minStake, pop, noEmptySeat, "the minimum");
        _assertRegisterReverts(Carol, publicKey, 2 * cfg.minStake, pop, noEmptySeat, "above it");
        _assertRegisterReverts(
            Carol,
            publicKey,
            cfg.minStake - 1,
            pop,
            IEtnaStaking.StakeTooLow.selector,
            "stake checked first"
        );
        _assertRegisterReverts(
            Carol,
            EtnaTestKeys.publicKey(_K1),
            cfg.minStake,
            EtnaVoteKeys.popSig(_K1, staking, Carol),
            IEtnaStaking.KeyAlreadyUsed.selector,
            "key checked first"
        );

        assertEq(staking.bondCount(), 4, "no bond issued");
        _assertBondForKey(EtnaTestKeys.ckAddr(_K5), false, 0, "key unused");
        for (uint8 seat; seat < 4; ++seat) {
            _assertBondInSeat(seat, true, seat, "seats kept");
        }
        assertEq(token.balanceOf(Carol), 2 * cfg.minStake, "nothing pulled");
    }

    function test_register_PopDigestIsEtnaStakingOnL2() external {
        assertEq(block.chainid, 167_001, "chain id");
        address o = Carol;
        bytes32 expected = keccak256(
            abi.encodePacked(
                hex"1901",
                keccak256(
                    abi.encode(
                        keccak256(
                            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                        ),
                        keccak256("EtnaStaking"),
                        keccak256("1"),
                        uint256(167_001),
                        address(staking)
                    )
                ),
                keccak256(abi.encode(keccak256("Register(address owner)"), o))
            )
        );
        assertEq(staking.registerDigest(o), expected, "digest");
        assertTrue(staking.registerDigest(Bob) != expected, "binds the owner");

        // The domain follows the current chain id rather than one cached at deployment.
        vm.chainId(167_002);
        assertTrue(staking.registerDigest(o) != expected, "binds the chain id");
    }

    function test_register_TakesTheSeatAnExitFreed() external {
        _register(_K1, Bob, MIN_STAKE);
        _register(_K2, Bob, MIN_STAKE);
        _register(_K3, Bob, MIN_STAKE);
        _requestExit(1);
        _assertBondInSeat(1, false, 0, "seat 1 freed");

        assertEq(_register(_K4, Carol, MIN_STAKE), 3, "bond id");
        _assertSeatOfBond(3, true, 1, "the new bond takes seat 1");
        _assertBondInSeat(1, true, 3, "seat 1");
        _assertBondInSeat(0, true, 0, "seat 0 unchanged");
        _assertBondInSeat(2, true, 2, "seat 2 unchanged");
        _assertBondInSeat(3, false, 0, "seat 3 still empty");
        _assertSeatOfBond(1, false, 0, "the exited bond");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K4)), bytes32(uint256(0x0101)), "new key");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K2)), bytes32(0), "exited key");
    }

    /// @dev Pause stops no entry point: a whole bond lifecycle runs while paused.
    function test_register_IgnoresPause() external {
        vm.prank(STAKING_OWNER);
        staking.pause();
        assertTrue(staking.paused(), "paused");

        uint256 bondId = _register(_K1, Bob, MIN_STAKE);
        _assertSeatOfBond(bondId, true, 0, "registered and seated");

        _fund(Bob, 1);
        vm.prank(Bob);
        staking.topUp(bondId, 1);
        _requestExit(bondId);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(Bob);
        staking.withdraw(bondId, Bob);
        assertEq(token.balanceOf(Bob), MIN_STAKE + 1, "withdrawn");
    }

    // ---------------------------------------------------------------
    // Key and proof-of-possession rejections
    // ---------------------------------------------------------------

    /// @dev Every invalid `key_decompression` vector case is rejected before anything is written:
    /// 32, 34, 64 and 65 bytes, hybrid and textual encodings, the prefixes 0x00, 0x01 and 0x04,
    /// X = p and above, and X = 5, which no curve point has.
    function test_register_RevertWhen_PublicKeyMalformed() external {
        string memory j = LibEtnaVectors.load();
        _fund(Bob, MIN_STAKE);
        // A valid proof of possession of another key: the key is rejected before the PoP check.
        bytes memory pop = EtnaVoteKeys.popSig(_CK_A, staking, Bob);
        bytes4 invalidPublicKey = LibEtnaKeys.InvalidPublicKey.selector;
        uint256 n = LibEtnaVectors.lengthAt(j, ".key_decompression");
        uint256 rejected;
        for (uint256 i; i < n; ++i) {
            string memory p = LibEtnaVectors.itemAt(".key_decompression", i);
            if (vm.parseJsonBool(j, string.concat(p, "valid"))) continue;
            bytes memory publicKey = LibEtnaVectors.bytesAt(j, string.concat(p, "public_key"));
            string memory label = string.concat(
                LibEtnaVectors.stringAt(j, string.concat(p, "name")),
                " (",
                LibEtnaVectors.stringAt(j, string.concat(p, "reason")),
                ")"
            );
            _assertRegisterReverts(Bob, publicKey, MIN_STAKE, pop, invalidPublicKey, label);
            ++rejected;
        }
        assertEq(rejected, 15, "rejection count");
        _assertRegisterReverts(Bob, hex"02", MIN_STAKE, "", invalidPublicKey, "before the PoP");

        assertEq(staking.bondCount(), 0, "no bond issued");
        _assertBondInSeat(0, false, 0, "seat 0 empty");
    }

    /// @dev Freshly signed proofs of possession that are malformed, out of range or bound to
    /// another owner, key, chain or staking contract are rejected.
    function test_register_RevertWhen_PopInvalid() external {
        _fund(Bob, MIN_STAKE);
        _fund(Carol, MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes32 digest = staking.registerDigest(Bob);
        bytes memory pop = EtnaTestKeys.sig65(_CK_A, digest);
        (bytes32 r, bytes32 s, uint8 v) = _split(pop);
        uint256 n = LibEtnaKeys.N;

        // Carol submits Bob's calldata: the digest names the caller, so the owner cannot change.
        _assertPopRejected(Carol, publicKey, pop, "copied transaction");
        _assertPopRejected(
            Bob, publicKey, EtnaVoteKeys.popSig(_CK_A, staking, David), "another owner"
        );
        _assertPopRejected(Bob, publicKey, EtnaTestKeys.sig65(_CK_B, digest), "another key");
        _assertPopRejected(
            Bob, publicKey, EtnaTestKeys.sig65(_CK_A, _digestOnChain(Bob, 167_002)), "another chain"
        );
        EtnaStaking other = _deploy(_config());
        _assertPopRejected(
            Bob, publicKey, EtnaVoteKeys.popSig(_CK_A, other, Bob), "another staking contract"
        );

        _assertPopRejected(Bob, publicKey, abi.encodePacked(r, s, v + 27), "v + 27");
        _assertPopRejected(Bob, publicKey, abi.encodePacked(r, s, uint8(2)), "v = 2");
        // The high-s twin recovers the same address; only the range check rejects it.
        bytes memory highS = abi.encodePacked(r, bytes32(n - uint256(s)), v ^ 1);
        assertEq(ecrecover(digest, (v ^ 1) + 27, r, bytes32(n - uint256(s))), vm.addr(_CK_A));
        _assertPopRejected(Bob, publicKey, highS, "high s");
        _assertPopRejected(Bob, publicKey, abi.encodePacked(bytes32(0), s, v), "r = 0");
        _assertPopRejected(Bob, publicKey, abi.encodePacked(r, bytes32(0), v), "s = 0");
        _assertPopRejected(Bob, publicKey, abi.encodePacked(bytes32(n), s, v), "r = n");
        _assertPopRejected(
            Bob, publicKey, abi.encodePacked(bytes32(uint256(5)), s, v), "unrecoverable r"
        );
        _assertPopRejected(Bob, publicKey, abi.encodePacked(r, s), "64 bytes");
        _assertPopRejected(Bob, publicKey, abi.encodePacked(pop, uint8(0)), "66 bytes");
        assertEq(staking.bondCount(), 0, "no bond issued");
        _assertBondForKey(vm.addr(_CK_A), false, 0, "key unused");

        // The valid proof of possession still registers the key: no rejection consumed it.
        vm.prank(Bob);
        staking.register(publicKey, MIN_STAKE, pop);
        assertEq(staking.bondAt(0).owner, Bob, "owner");
    }

    /// @dev The other prefix encodes the negated point (x, p - y), a valid key whose private key
    /// is n - pk. A PoP by pk does not match it; the negated key's own PoP registers it, under
    /// its own address.
    function test_register_RevertWhen_ParityFlippedKeyHasNoMatchingPop() external {
        (uint8 prefix, bytes32 x) = EtnaTestKeys.fallbackKey(_CK_A);
        bytes memory flipped = abi.encodePacked(prefix ^ 1, x);
        _fund(Bob, MIN_STAKE);
        _assertPopRejected(
            Bob, flipped, EtnaVoteKeys.popSig(_CK_A, staking, Bob), "PoP of the other point"
        );

        uint256 negated = LibEtnaKeys.N - _CK_A;
        assertEq(EtnaTestKeys.publicKey(negated), flipped, "the negated key");
        bytes memory pop = EtnaVoteKeys.popSig(negated, staking, Bob);
        vm.prank(Bob);
        staking.register(flipped, MIN_STAKE, pop);
        assertEq(staking.bondAt(0).ckPrefix, prefix ^ 1, "prefix");
        assertEq(staking.bondAt(0).ckX, x, "x");
        _assertBondForKey(vm.addr(negated), true, 0, "negated key used");
        _assertBondForKey(vm.addr(_CK_A), false, 0, "original key unused");
        assertEq(_keySeatWord(vm.addr(negated)), bytes32(uint256(0x0001)), "negated key seated");
    }

    /// @dev The compressed key of any private key registers with its PoP, and the bond holds that
    /// key.
    function testFuzz_register_AcceptsAnyKey(uint256 _pk) external {
        _pk = bound(_pk, 1, LibEtnaKeys.N - 1);
        Vm.Wallet memory wallet = vm.createWallet(_pk);
        uint8 prefix = uint8(2 + (wallet.publicKeyY & 1));
        bytes memory publicKey = abi.encodePacked(prefix, bytes32(wallet.publicKeyX));
        _fund(Bob, MIN_STAKE);
        bytes memory pop = EtnaTestKeys.sig65(_pk, staking.registerDigest(Bob));

        vm.prank(Bob);
        uint256 bondId = staking.register(publicKey, MIN_STAKE, pop);
        assertEq(staking.bondAt(bondId).ckPrefix, prefix, "prefix");
        assertEq(uint256(staking.bondAt(bondId).ckX), wallet.publicKeyX, "x");
        _assertBondForKey(wallet.addr, true, bondId, "key used");
        assertEq(_keySeatWord(wallet.addr), bytes32(uint256(0x0001)), "key seated");
    }

    // ---------------------------------------------------------------
    // Views and unissued ids
    // ---------------------------------------------------------------

    function test_views_ReturnAbsenceForUnissuedEmptyAndOutOfRange() external {
        for (uint256 pk = _K1; pk <= _K4; ++pk) {
            _register(pk, Bob, MIN_STAKE);
        }

        _assertSeatOfBond(9, false, 0, "unissued bond");
        _assertBondInSeat(4, false, 0, "empty seat");
        _assertBondInSeat(127, false, 0, "the last seat, empty");
        _assertBondInSeat(200, false, 0, "seat above 128");
        _assertBondForKey(EtnaTestKeys.ckAddr(_K5), false, 0, "unused key");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K5)), bytes32(0), "unused key's seat word");
        assertEq(staking.missCount(200), 0, "miss count above 128");
        assertFalse(staking.forfeited(9), "unissued bond's forfeiture flag");

        IEtnaStaking.Bond memory bond = staking.bondAt(9);
        assertEq(bond.owner, address(0), "unissued owner");
        assertEq(bond.ckPrefix, 0, "unissued prefix");
        assertFalse(bond.withdrawn, "unissued withdrawn");
        assertFalse(bond.holdsSeat, "unissued holdsSeat");
        assertEq(bond.seat, 0, "unissued seat");
        assertEq(bond.exitHeight, 0, "unissued exit");
        assertEq(bond.ckX, bytes32(0), "unissued x");
        assertEq(bond.effStake, 0, "unissued effStake");

        (uint256 height, uint256 totalStake, IEtnaStaking.SeatMember[] memory members) =
            staking.snapshot();
        assertEq(height, 0, "no snapshot height");
        assertEq(totalStake, 0, "no snapshot total");
        assertEq(members.length, 0, "registration writes no snapshot record");
    }

    function test_views_SeatZeroAndBondIdsAreNotAbsence() external {
        _register(_K1, Bob, MIN_STAKE);
        _register(_K2, Bob, MIN_STAKE);
        _register(_K3, Bob, MIN_STAKE);
        _requestExit(0);
        assertEq(_register(_K4, Carol, MIN_STAKE), 3, "bond id");

        _assertBondInSeat(0, true, 3, "seat 0 holds bond 3");
        _assertSeatOfBond(3, true, 0, "bond 3 holds seat 0");
        _assertSeatOfBond(0, false, 0, "bond 0 holds no seat");
        _assertBondForKey(EtnaTestKeys.ckAddr(_K1), true, 0, "bond 0's key");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K4)), bytes32(uint256(0x0001)), "seat 0 word");
    }

    /// @dev Default storage at an unissued id reads as an exit at block 0, a zero balance and the
    /// zero owner, which past the withdrawal delay would satisfy `withdraw`, open to anyone with
    /// a zero balance. Every state-changing call on such an id still reverts `UnknownBond` before
    /// writing anything, and registering the id afterwards yields a fresh bond.
    function test_unissuedIds_RevertWithoutWritesThenRegisterFresh() external {
        vm.roll(WITHDRAWAL_DELAY + 1);
        _assertUnknownBondWithoutWrites(0, "id 0 of an empty contract");

        _register(_K1, Bob, MIN_STAKE);
        _register(_K2, Bob, MIN_STAKE);
        uint256 next = staking.bondCount();
        _assertUnknownBondWithoutWrites(next, "the next id");
        _assertUnknownBondWithoutWrites(2 ** 200, "2^200");

        uint256 amount = MIN_STAKE + 7;
        uint256 bondId = _register(_K3, Carol, amount);
        assertEq(bondId, next, "the next id is issued");
        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        assertEq(bond.owner, Carol, "owner");
        assertEq(bond.effStake, amount, "effStake");
        assertEq(bond.exitHeight, NO_EXIT, "no exit set");
        assertFalse(bond.withdrawn, "not withdrawn");
        _assertSeatOfBond(bondId, true, 2, "seated");

        vm.expectRevert(IEtnaStaking.ExitNotSet.selector);
        vm.prank(Carol);
        staking.withdraw(bondId, Carol);

        uint256 exitAt = block.number;
        _requestExit(bondId);
        vm.roll(exitAt + 302_401);
        vm.expectRevert(IEtnaStaking.WithdrawalNotReady.selector);
        vm.prank(Carol);
        staking.withdraw(bondId, Carol);

        vm.roll(exitAt + 302_402);
        vm.prank(Carol);
        staking.withdraw(bondId, Carol);
        assertEq(token.balanceOf(Carol), amount, "paid");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev `topUp` and `requestExit` from the zero address, which default storage names as the
    /// owner, and `withdraw` from Alice, each revert `UnknownBond` without a storage write.
    function _assertUnknownBondWithoutWrites(
        uint256 _bondId,
        string memory _label
    )
        private
    {
        _assertUnknownWithoutWrites(
            address(0),
            abi.encodeCall(staking.topUp, (_bondId, 1)),
            string.concat(_label, ": topUp")
        );
        _assertUnknownWithoutWrites(
            address(0),
            abi.encodeCall(staking.requestExit, (_bondId)),
            string.concat(_label, ": requestExit")
        );
        _assertUnknownWithoutWrites(
            Alice,
            abi.encodeCall(staking.withdraw, (_bondId, Alice)),
            string.concat(_label, ": withdraw")
        );
    }

    function _assertUnknownWithoutWrites(
        address _caller,
        bytes memory _call,
        string memory _label
    )
        private
    {
        vm.record();
        vm.prank(_caller);
        (bool ok, bytes memory err) = address(staking).call(_call);
        (, bytes32[] memory writes) = vm.accesses(address(staking));
        assertFalse(ok, _label);
        assertEq(err, abi.encodeWithSelector(IEtnaStaking.UnknownBond.selector), _label);
        assertEq(writes.length, 0, string.concat(_label, ": no storage write"));
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
            _caller, _publicKey, MIN_STAKE, _pop, LibEtnaKeys.InvalidSignature.selector, _label
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
        try staking.register(_publicKey, _amount, _pop) returns (uint256 bondId) {
            assertTrue(false, string.concat(_label, ": registered bond ", vm.toString(bondId)));
        } catch (bytes memory err) {
            assertEq(err, abi.encodeWithSelector(_error), _label);
        }
    }

    /// @dev The registration digest of `_owner` at `staking`, computed under `_chainId`.
    function _digestOnChain(
        address _owner,
        uint256 _chainId
    )
        private
        returns (bytes32 digest_)
    {
        uint256 chainId = block.chainid;
        vm.chainId(_chainId);
        digest_ = staking.registerDigest(_owner);
        vm.chainId(chainId);
    }

    /// @dev Splits a 65-byte signature `R ‖ S ‖ V`.
    function _split(bytes memory _sig) private pure returns (bytes32 r_, bytes32 s_, uint8 v_) {
        assembly {
            r_ := mload(add(_sig, 0x20))
            s_ := mload(add(_sig, 0x40))
            v_ := byte(0, mload(add(_sig, 0x60)))
        }
    }
}
