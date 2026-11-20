"""Focused counterexamples for the funded Registry journal observer."""

import importlib.util
from functools import lru_cache
import os
from pathlib import Path
import sys
import unittest

A = int("aa" * 20, 16)
ADMIN = 0x3333
PUBLIC = 0x4444
REGISTRY = int("22" * 20, 16)
SINK = 0x5555


class RegistryFundingTest(unittest.TestCase):
    @classmethod
    @lru_cache(maxsize=1)
    def load_observer(cls):
        source_dir = Path(os.environ.get(
            "ETNA_REGISTRY_FUNDING_CONFORMANCE",
            Path(__file__).resolve().parents[1] / "conformance",
        ))
        source = source_dir / "run_registry_funding.py"
        if source.is_file():
            sys.path.insert(0, str(source_dir))
            spec = importlib.util.spec_from_file_location("etna_registry_funding", source)
            module = importlib.util.module_from_spec(spec)
            sys.modules[spec.name] = module
            spec.loader.exec_module(module)
            return module
        return None

    def setUp(self):
        self.observer = self.load_observer()
        self.assertIsNotNone(self.observer, "Y04 funded Registry audit API absent")

    def test_execution_balance_charges_pending_and_keeps_readiness(self):
        self.observer.require_forfeiture(
            (4, 5, 14, 0), (0, 4, 14, 5), (9, 5),
        )

    def test_penalty_must_debit_pending_principal(self):
        with self.assertRaisesRegex(ValueError, "pending debit"):
            self.observer.require_forfeiture(
                (4, 5, 14, 0), (0, 5, 14, 5), (9, 5),
            )

    def test_authorization_time_balance_cannot_set_execution_penalty(self):
        with self.assertRaisesRegex(ValueError, "execution balance"):
            self.observer.require_forfeiture(
                (4, 5, 14, 0), (2, 5, 14, 2), (4, 2),
            )

    def test_public_cannot_withdraw_pending_only_principal(self):
        with self.assertRaisesRegex(ValueError, "public withdrawal"):
            self.observer.require_attempt(
                "withdraw_public", PUBLIC, 1, 1060, True, b"",
            )

    def test_deadline_equality_succeeds(self):
        self.observer.require_attempt("forfeit", ADMIN, 1, 1060, True, b"")

    def test_deadline_plus_one_requires_authorization_expired(self):
        with self.assertRaisesRegex(ValueError, "deadline"):
            self.observer.require_attempt(
                "forfeit_late", ADMIN, 0, 1061, False, bytes(4),
            )

    def test_executor_cannot_be_relabeled_as_bond_owner(self):
        with self.assertRaisesRegex(ValueError, "actor"):
            self.observer.require_attempt("forfeit", A, 1, 1060, True, b"")

    def test_boolean_cannot_alias_mock_generation_one(self):
        with self.assertRaisesRegex(ValueError, "generation"):
            self.observer.require_attempt("forfeit", ADMIN, True, 1060, True, b"")

    def test_balancing_transfer_may_not_draw_from_unknown_account(self):
        with self.assertRaisesRegex(ValueError, "token route"):
            self.observer.require_transfers(
                "forfeit", [(0x7777, SINK, 5)],
            )

    def test_padding_or_extra_transfer_cannot_hide_a_new_allocation(self):
        with self.assertRaisesRegex(ValueError, "token route"):
            self.observer.require_transfers(
                "forfeit", [(REGISTRY, SINK, 5), (0x7777, A, 1)],
            )


class CaptureChecks:
    """Additional checks run when an authorized native capture directory is supplied."""

    @classmethod
    def setUpClass(cls):
        import json
        cls.observer = RegistryFundingTest.load_observer()
        root = Path(os.environ["ETNA_REGISTRY_FUNDING_CAPTURE"])
        cls.raw = (root / "stdout.log").read_bytes()
        cls.stderr = (root / "stderr.log").read_bytes()
        cls.execution = (root / "execution.json").read_bytes()
        cls.workspace = Path(os.environ["ETNA_REGISTRY_FUNDING_WORKSPACE"])
        suite, = json.loads(cls.raw).values()
        leaf, = suite["test_results"].values()
        envelope = bytes.fromhex(leaf["logs"][-1]["data"][2:])
        cls.receipt = envelope[64:64+int.from_bytes(envelope[32:64], "big")]
        cls.positions = {}
        pos = 256
        while pos < len(cls.receipt):
            n = int.from_bytes(cls.receipt[pos:pos+32], "big")
            assert 0 < n <= len(cls.receipt) - pos - 32
            start = pos + 64
            name = cls.receipt[start+32:start+64].rstrip(b"\0").decode("ascii")
            cls.positions[name] = start
            pos += 32 + n

    def setUp(self):
        healthy = self.observer.current_receipt(
            self.workspace, self.raw, execution=self.execution, stderr=self.stderr)
        self.assertEqual(healthy["status"], "Success")
        self.assertEqual(healthy["totalAllocated"], 15)
        self.assertEqual(healthy["bondPrincipal"], [0, 4, 4])
        self.assertEqual(healthy["transfers"], 6)

    def changed(self, name, offset, new):
        start = self.positions[name]+offset
        original = self.receipt[start:start+len(new)]
        self.assertNotEqual(original, new)
        corrupt = self.receipt[:start] + new + self.receipt[start+len(new):]
        self.assert_corrupt_receipt(corrupt)

    @staticmethod
    def word(n):
        return n.to_bytes(32, "big")

    def test_order_attribution(self):
        self.changed("mock_generation", 32, b"recover".ljust(32, b"\0"))

    def test_execution_actor(self):
        self.changed("forfeit", 4*32, self.word(A))

    def test_principal_backing_despite_unchanged_cash(self):
        self.changed("forfeit", (104+44)*32, self.word(5))

    def test_funded_public_offer_and_deadline(self):
        self.changed("topup_public", (9+72)*32, self.word(0))
        self.changed("forfeit_late", 3*32, self.word(1060))

    def test_restore_digest_and_raw_clock(self):
        self.changed("restore_late", 199*32, bytes(32))
        self.changed("restore_public", 2*32, self.word(15))

    def test_committed_lifetime_key(self):
        self.changed("register_fresh_a", (104+47)*32, bytes(32))

    def test_withdrawal_data(self):
        name = "withdraw_public"
        base = self.positions[name]
        offset = int.from_bytes(self.receipt[base+8*32:base+9*32], "big")
        self.changed(name, offset+32, bytes(4))

    def test_token_approval_not_mint(self):
        name = "approve_payout"
        base = self.positions[name]
        offset = int.from_bytes(self.receipt[base+7*32:base+8*32], "big")
        mint = bytes.fromhex("40c10f19")
        self.changed(name, offset+32, mint)

    def test_auxiliary_frame_and_unknown_actor(self):
        name = "forfeit"
        base = self.positions[name]
        frames = int.from_bytes(self.receipt[base+202*32:base+203*32], "big")
        offset = int.from_bytes(self.receipt[base+frames+32:base+frames+64], "big")
        self.changed(name, frames+32+offset+3*32, self.word(0x7777))

    def test_no_funding_from_another_account(self):
        name = "mint_a"
        base = self.positions[name]
        input_offset = int.from_bytes(self.receipt[base+7*32:base+8*32], "big")
        self.changed(name, input_offset+32+4, self.word(0x7777))

    def test_mock_generation_and_covering_snapshot(self):
        self.changed("forfeit", (9+4)*32, bytes(32))
        self.changed("mock_covered", (104+4)*32, self.word(1 | 14 << 48))

    def test_executed_forfeit_keeps_authorized_calldata(self):
        base = self.positions["forfeit"]
        offset = int.from_bytes(self.receipt[base+7*32:base+8*32], "big")
        self.changed("forfeit", offset+32+4+3*32, self.word(1061))

    def test_deployment_actor(self):
        self.changed("setup", 4*32, self.word(A))

    def test_audit_rejects_trailing_record(self):
        with self.assertRaises(ValueError):
            self.observer.audit_journal(self.receipt+bytes(32))

    def frame_offset(self, name, index):
        base = self.positions[name]
        def number(pos):
            return int.from_bytes(self.receipt[pos:pos+32], "big")
        array = number(base + 202*32)
        self.assertGreater(number(base+array), index)
        table = array + 32
        return table + number(base+table+index*32)

    def test_nested_call_depth_and_initialized(self):
        name = "register_a"
        modexp = self.frame_offset(name, 4)
        self.changed(name, modexp + 13*32, self.word(1))
        self.changed(name, modexp + 5*32, self.word(1))

    def test_resumption_preserves_caller_and_revert_context(self):
        for name, reverted in (("topup_a", 1), ("topup_public", 0)):
            resume = self.frame_offset(name, 4)
            self.changed(name, resume + 4*32, self.word(0x7777))
            self.changed(name, resume + 11*32, self.word(reverted))

    def test_storage_record_matches_frame_owner_and_values(self):
        name = "mint_a"
        base = self.positions[name]
        token = self.frame_offset(name, 1)
        array = token + int.from_bytes(self.receipt[base+token+12*32:base+token+13*32], "big")
        self.changed(name, array+32+3*32, self.word(9))  # SLOAD previous value
        self.changed(name, array+32+6*32, self.word(REGISTRY))  # SSTORE belongs to token

    def test_spurious_auxiliary_frame_on_authorization(self):
        name = "authorize"
        base = self.positions[name]
        word = self.word
        frames = int.from_bytes(self.receipt[base+202*32:base+203*32], "big")
        self.assertEqual(self.receipt[base+frames:base+frames+32], word(0))
        driver = int.from_bytes(self.receipt[32:64], "big")
        # Empty dynamic code, calldata and storage follow a canonical 14-word access head.
        values = (0, 1, 6, driver, 0x7777, 0, 0, 0, 448, 0, 480, 1, 512, 0, 0, 0, 0)
        addition = word(32) + b"".join(word(v) for v in values)
        old_size = int.from_bytes(self.receipt[base-64:base-32], "big")
        tail = base + frames
        corrupt = (self.receipt[:base-64] + word(old_size+len(addition))
                   + self.receipt[base-32:tail] + word(1) + addition + self.receipt[tail+32:])
        self.assert_corrupt_receipt(corrupt)

    def assert_corrupt_receipt(self, corrupt):
        import hashlib
        import json
        native = json.loads(self.raw)
        suite, = native.values()
        leaf, = suite["test_results"].values()
        leaf["logs"][-1]["data"] = "0x" + (self.word(32) + self.word(len(corrupt)) + corrupt).hex()
        raw = json.dumps(native).encode()
        record = json.loads(self.execution)
        record["stdoutSha256"] = hashlib.sha256(raw).hexdigest()
        with self.assertRaises(ValueError):
            self.observer.current_receipt(
                self.workspace, raw, execution=json.dumps(record).encode(), stderr=self.stderr)

    def storage_offset(self, name, frame):
        head = self.frame_offset(name, frame)
        pointer = self.positions[name] + head + 12*32
        return head + int.from_bytes(self.receipt[pointer:pointer+32], "big")

    def test_forfeit_read_cannot_use_equal_valued_unrelated_slot(self):
        array = self.storage_offset("forfeit", 5)
        offset = array + 32 + 5*192 + 32  # slot of the flag SLOAD
        flag = self.observer.location(int(self.observer.public_inputs()["keys"][0]["entry_key"],16),
                                      self.observer.FORFEIT)
        start = self.positions["forfeit"] + offset
        self.assertEqual(self.receipt[start:start+32], self.word(flag))
        self.changed("forfeit", offset, self.word(101))  # zero pendingOwner vs. zero lifetime flag

    def test_forfeit_different_slot_writes_keep_source_order(self):
        array = self.storage_offset("forfeit", 5)
        offset = array + 32 + 11*192
        start = self.positions["forfeit"] + offset
        flag = self.receipt[start:start+192]
        key_x = self.receipt[start+192:start+384]
        self.assertEqual((flag[64:96],key_x[64:96]), (self.word(1),self.word(1)))
        self.assertNotEqual(flag[32:64], key_x[32:64])
        self.changed("forfeit", offset, key_x + flag)

    def test_confirmation_store_follows_snapshot_getter(self):
        # Re-encode the full frame offset table after moving both confirmation rows
        # across the getter. Preserve the complete frame and step lengths in aggregate.
        name = "confirm"
        base = self.positions[name]
        def number(start):
            return int.from_bytes(self.receipt[start:start+32], "big")
        array = base + number(base+202*32)
        count = number(array)
        self.assertEqual(count, 8)
        table = array + 32
        offsets = [number(table+32*i) for i in range(count)]
        end = base-32 + number(base-64)
        bounds = [table+offset for offset in offsets] + [end]
        frames = [self.receipt[left:right] for left,right in zip(bounds,bounds[1:])]
        def storage(frame):
            off = int.from_bytes(frame[12*32:13*32], "big")
            size = int.from_bytes(frame[off:off+32], "big")
            self.assertEqual(off+32+192*size, len(frame))
            return frame[:off], size, frame[off+32:]
        first, nfirst, early_rows = storage(frames[5])
        last, nlast, confirmation_rows = storage(frames[7])
        self.assertEqual((nfirst,nlast), (3,2))
        self.assertEqual(frames[6][2*32:3*32], self.word(3))  # actual static snapshot call
        frames[5] = first + self.word(nfirst+nlast) + early_rows + confirmation_rows
        frames[7] = last + self.word(0)
        cursor = count*32
        new_offsets = []
        for frame in frames:
            new_offsets.append(self.word(cursor))
            cursor += len(frame)
        joined = b"".join(new_offsets + frames)
        self.assertEqual(len(joined), end-table)
        self.assert_corrupt_receipt(self.receipt[:table]+joined+self.receipt[end:])

    def test_capture_metadata_with_same_native_output(self):
        import json
        record = json.loads(self.execution)
        fields = {"claim": "registry-origin-selection", "nativeCommit": "0"*40,
                  "returncode": False, "timedOut": 0, "cwd": ".", "stdoutSha256": "0"*64,
                  "sourceFiles": {}, "forgeArgv": record["forgeArgv"][:-1]}
        for field, replacement in fields.items():
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.observer.current_receipt(self.workspace, self.raw,
                    execution=json.dumps({**record, field: replacement}).encode(), stderr=self.stderr)


def native_capture_suite():
    """Explicit unittest entry point; the caller must provide the genuine capture and workspace."""
    class NativeFundingTest(CaptureChecks, unittest.TestCase):
        pass
    return unittest.defaultTestLoader.loadTestsFromTestCase(NativeFundingTest)
