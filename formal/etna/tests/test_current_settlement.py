"""Current Appendix A cut bytes and immutable proof transaction admission."""
import sys
import unittest
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "conformance"))
from current_settlement import Context, Cut, capture, cut_preimage, land, range_hash
from run_comet_apphash import keccak256


def word(value):
    return value.to_bytes(32, "big")


class CurrentSettlement(unittest.TestCase):
    def setUp(self):
        self.cuts = tuple(Cut(h, word(91 + h), word(180 + h), h - 6)
                          for h in range(6, 10))
        self.blobs = tuple(bytes([1]) + word(h)[1:] for h in (7, 8, 9))
        self.context = Context(1, 167000, 0x1111, 0x2222, word(333), word(444), word(555), 0)
        self.job = capture(0, 0, self.cuts, self.blobs, self.context)
        self.call = dict(generation=0, start=6, origin=(0, self.cuts[0]),
                         checkpoint=self.cuts[1], fi_head=1, now=2, window=4,
                         capacity=3, blobs=self.blobs, leaves=self.job.leaves,
                         proofs=(self.job.statement, self.job.statement))

    def test_four_static_words(self):
        self.assertEqual(cut_preimage(self.cuts[2]),
                         word(8) + word(99) + word(188) + word(2))

    def test_single_block_uses_empty_inner_list(self):
        job = capture(0, 0, self.cuts[:2], self.blobs[:1], self.context)
        self.assertEqual(job.leaves, ())
        expected = keccak256(b"ETNA_LAND_CUTS_V1".ljust(32, b"\0") + word(0)
                             + word(6) + word(7) + keccak256(b""))
        self.assertEqual(range_hash(0, 6, 7, ()), expected)

    def test_ordered_only_interior_leaves(self):
        self.assertEqual(self.job.leaves, tuple(keccak256(cut_preimage(c))
                                                for c in self.cuts[1:-1]))

    def test_signed_generation_survives_recovery_but_cannot_land(self):
        with self.assertRaises(ValueError):
            land(self.job, **dict(self.call, generation=1, start=6, checkpoint=self.cuts[0], fi_head=0))

    def test_retained_old_origin_is_legal_for_fresh_job(self):
        job = capture(1, 2, self.cuts[1:3], self.blobs[1:2], self.context)
        args = dict(self.call, generation=1, start=7, origin=(0, self.cuts[1]),
                    now=3, blobs=job.blobs, leaves=(), proofs=(job.statement,) * 2)
        self.assertEqual(land(job, **args), (1, 7, self.cuts[2], 3))

    def test_suffix_data_refused(self):
        with self.assertRaises(ValueError):
            land(self.job, **dict(self.call, blobs=self.blobs[1:]))

    def test_checkpoint_fi_matches_record(self):
        with self.assertRaises(ValueError):
            land(self.job, **dict(self.call, fi_head=0))

    def test_other_backend_binding(self):
        with self.assertRaises(ValueError):
            land(self.job, **dict(self.call, proofs=(self.job.statement, word(77))))

    def test_interior_position_checked(self):
        with self.assertRaises(ValueError):
            land(self.job, **dict(self.call, leaves=self.job.leaves[::-1]))

    def test_cut_component_identity(self):
        altered = replace(self.cuts[1], comet=word(1234))
        with self.assertRaises(ValueError):
            land(self.job, **dict(self.call, checkpoint=altered))

    def test_original_transaction_at_each_interior(self):
        for c in self.cuts[1:-1]:
            with self.subTest(height=c.height):
                self.assertEqual(land(self.job, **dict(self.call, checkpoint=c, fi_head=c.fi)),
                                 (0, c.height, self.cuts[-1], 2))

    def test_complete_statement_encoding(self):
        job = self.job
        p, h = self.cuts[0], self.cuts[-1]
        words = (b"TAIKO_ETNA_LAND_V1".ljust(32, b"\0"), word(1), word(167000),
                 word(0x1111), word(0x2222), word(0), word(p.height), p.el, p.comet,
                 word(333), word(h.height), h.el, h.comet, word(444), word(0),
                 word(555), keccak256(b"".join(self.blobs)), word(p.fi), word(h.fi),
                 word(0), range_hash(0, p.height, h.height, job.leaves))
        self.assertEqual(job.statement, keccak256(b"".join(words)))

    def test_caller_changes_do_not_rewrite_capture(self):
        args = dict(generation=0, reference=0, cuts=list(self.cuts),
                    blobs=list(self.blobs), context=self.context)
        job = capture(**args)
        args["cuts"].reverse()
        args["blobs"][0] = word(123)
        args["context"] = self.context._replace(snapshot=10)
        self.assertEqual((job.cuts, job.blobs, job.statement),
                         (self.cuts, self.blobs, self.job.statement))

    def test_overlong_capture_refuses_before_iteration(self):
        class Oversized:
            def __len__(self):
                return 1 << 40

            def __iter__(self):
                raise AssertionError("oversized range was read")

        with self.assertRaises(ValueError):
            capture(0, 0, Oversized(), Oversized(), self.context)

    def test_wrong_leaf_count_refuses_before_iteration(self):
        class TooManyLeaves:
            def __len__(self):
                return 1 << 40

            def __iter__(self):
                raise AssertionError("oversized leaves were read")

        with self.assertRaises(ValueError):
            land(self.job, **dict(self.call, leaves=TooManyLeaves()))

    def test_forged_mutable_job_fields_are_rejected(self):
        for job in (self.job._replace(statement=bytearray(self.job.statement)),
                    self.job._replace(leaves=tuple(bytearray(x) for x in self.job.leaves)),
                    self.job._replace(generation=False),
                    self.job._replace(cuts=(self.cuts[0], object(), *self.cuts[2:]))):
            with self.subTest(job=job), self.assertRaises(ValueError):
                land(job, **self.call)

    def test_generation_snapshot_enters_proof(self):
        fresh = self.context._replace(snapshot=2)
        job = capture(1, 2, self.cuts[1:3], self.blobs[1:2], fresh)
        stale = capture(1, 2, self.cuts[1:3], self.blobs[1:2], self.context)
        self.assertNotEqual(job.statement, stale.statement)

    def test_operational_generation_width(self):
        g = (1 << 48) - 1
        job = capture(g, 0, self.cuts, self.blobs, self.context)
        args = dict(self.call, generation=g, origin=(g, self.cuts[0]),
                    proofs=(job.statement,) * 2)
        self.assertEqual(land(job, **args)[0], g)
        with self.assertRaises(ValueError):
            capture(g + 1, 0, self.cuts, self.blobs, self.context)
        with self.assertRaises(ValueError):
            land(job, **dict(args, generation=g + 1))
        with self.assertRaises(ValueError):
            land(job, **dict(args, origin=(g + 1, self.cuts[0])))
