"""Independent witness obligations over the actual ordered TLC state frames."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "conformance"))
from proving_recovery import require_fresh_progress


class RecoveryProgress(unittest.TestCase):
    def test_empty_trace_has_no_fresh_progress(self):
        with self.assertRaises(ValueError):
            require_fresh_progress([])

    def test_static_claim_is_not_a_live_capture(self):
        with self.assertRaises(ValueError):
            require_fresh_progress([{"generation": 1, "included": 2}])

    def test_raw_symbolic_statement_tag_must_be_integer(self):
        from proving_recovery import check_capture, initial
        a, b = (6, 6, 0, 0), (7, 7, 207, 1)
        pre = dict(initial(1), head=7, canonical=(a, b))
        statement = (1, 1, 167000, 4369, 8738, 0, 6, 6, 0, 333, 7, 7, 207,
                     407, 0, 500, (7,), 0, 1, 0, (2, 0, 6, 7, ()))
        info = dict(generation=0, reference=0, dependency=0, cuts=(a, b), data=(7,),
                    statement=statement)
        self.assertEqual(check_capture(pre, info).cuts[-1].height, 7)
        with self.assertRaises(ValueError):
            check_capture(pre, dict(info, statement=(True,) + statement[1:]))

    def test_fixed_last_offers_keep_distinct_references(self):
        from proving_recovery import fixed_audit, initial, updated
        cuts = ((6, 6, 0, 0),) + tuple((h, h, h+200, h-6) for h in range(7, 11))
        data = (7, 8, 9, 10)
        st = (1, 1, 167000, 4369, 8738, 0, 6, 6, 0, 333, 10, 10, 210,
              410, 0, 500, data, 0, 4, 0, (2, 0, 6, 10, cuts[1:-1]))
        job = dict(generation=0, reference=0, dependency=0, cuts=cuts, data=data, statement=st)
        frames = [dict(initial(4), head=10, canonical=cuts, now=1, jobs=(job, ()),
                       proofs=((st, st), ((), ())), published=(data, ()),
                       available=(True, True), privateHistory=True)]
        for h in (7, 8, 9, 10):
            p = frames[-1]
            frames.append(dict(p, included=h, fiHead=h-6, now=min(4, h-5),
                               records=updated(p["records"], h-6, (0, h-1, cuts[h-6], h-6)),
                               applied=tuple(int(6 < i <= h) for i in range(6, 11))))
        def attempt(p, h, t, choice):
            original = data[p-6:h-6]
            span = cuts[p-6:h-5]
            stmt = (1, 1, 167000, 4369, 8738, 0, p, p, span[0][2], 333, h, h,
                    200+h, 400+h, t, 500+t, original, p-6, h-6, 0,
                    (2, 0, p, h, span[1:-1]))
            incoming = dict(generation=0, reference=t, dependency=0, cuts=span,
                            data=original, statement=stmt)
            return choice, incoming, (stmt, stmt), original

        calls = [(0, (), (), ())] + [attempt(h-1, h, h-7, 1) for h in range(7, 11)]
        self.assertEqual(fixed_audit(frames, calls)[-1], ("short", 9, 10, 3))
        long_call = (2, job, (st, st), data)
        self.assertEqual(fixed_audit(frames, calls[:-1] + [long_call])[-1], ("long", 9, 10, 0))
        for altered in (attempt(6, 10, 3, 1), (1, job, (st, st), data),
                        (2, job, (st, ()), data), (2, job, (st, st), data[1:])):
            with self.subTest(altered=altered), self.assertRaises(ValueError):
                fixed_audit(frames, calls[:-1] + [altered])
