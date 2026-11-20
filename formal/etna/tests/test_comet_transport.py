import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "conformance" / "run_comet_transport.py"
SPEC = importlib.util.spec_from_file_location("etna_test_comet_transport", RUNNER)
TRANSPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRANSPORT)


def receipt():
    """Independent minimal evidence used to exercise the receipt comparison boundary."""
    return {
        "calls": [
            {
                "requestedChain": "chain-A",
                "attempts": [
                    {
                        "pipe": 1, "request": {"chain": "chain-A", "vote": {"wire": "0a"}},
                        "wireRead": "012a", "wireResponse": {"union": "SignedVoteResponse"},
                    }
                ],
                "after": {"signature": "c0ffee", "nanos": 123},
                "result": {"class": "remote", "remote": {"code": 0, "description": "refused"}},
            }
        ],
        "cleanup": {"retryWaitObserved": False, "joined": True},
    }


class ReceiptBoundaryTest(unittest.TestCase):
    def assert_rejected(self, observed, expected, path):
        with self.assertRaises(ValueError) as failure:
            TRANSPORT.compare_receipt(observed, expected)
        self.assertEqual(str(failure.exception), "receipt value mismatch at " + path)

    def test_matching_evidence(self):
        expected = receipt()
        TRANSPORT.compare_receipt(copy.deepcopy(expected), expected)

    def test_rejects_aliased_request_chain(self):
        expected = receipt()
        observed = copy.deepcopy(expected)
        observed["calls"][0]["attempts"][0]["request"]["chain"] = "chain-B"
        self.assert_rejected(observed, expected, "$.calls[0].attempts[0].request.chain")

    def test_rejects_aliased_attempt_vote(self):
        expected = receipt()
        observed = copy.deepcopy(expected)
        observed["calls"][0]["attempts"][0]["request"]["vote"]["wire"] = "0b"
        self.assert_rejected(observed, expected, "$.calls[0].attempts[0].request.vote.wire")

    def test_rejects_wrong_response_union(self):
        expected = receipt()
        observed = copy.deepcopy(expected)
        observed["calls"][0]["attempts"][0]["wireResponse"]["union"] = "PingResponse"
        self.assert_rejected(observed, expected, "$.calls[0].attempts[0].wireResponse.union")

    def test_rejects_lost_client_assignment(self):
        expected = receipt()
        observed = copy.deepcopy(expected)
        observed["calls"][0]["after"]["signature"] = ""
        self.assert_rejected(observed, expected, "$.calls[0].after.signature")

    def test_rejects_full_reply_aliased_to_truncated_observation(self):
        expected = receipt()
        expected["calls"][0]["attempts"][0]["wireRead"] = "012a00"
        observed = copy.deepcopy(expected)
        observed["calls"][0]["attempts"][0]["wireRead"] = "012a"
        self.assert_rejected(observed, expected, "$.calls[0].attempts[0].wireRead")

    def test_rejects_extra_retry_after_typed_refusal(self):
        expected = receipt()
        observed = copy.deepcopy(expected)
        first = observed["calls"][0]["attempts"][0]
        observed["calls"][0]["attempts"].append(copy.deepcopy(first))
        self.assert_rejected(observed, expected, "$.calls[0].attempts")

    def test_rejects_exhaustion_misclassified_as_typed_refusal(self):
        expected = receipt()
        expected["calls"][0]["result"] = {"class": "exhausted-timeout", "remote": None}
        observed = copy.deepcopy(expected)
        observed["calls"][0]["result"]["class"] = "remote"
        self.assert_rejected(observed, expected, "$.calls[0].result.class")

    def test_rejects_cancellation_without_observed_retry_wait(self):
        expected = receipt()
        expected["cleanup"]["retryWaitObserved"] = True
        observed = copy.deepcopy(expected)
        observed["cleanup"]["retryWaitObserved"] = False
        self.assert_rejected(observed, expected, "$.cleanup.retryWaitObserved")

    def test_rejects_numeric_boolean_alias(self):
        expected = receipt()
        observed = copy.deepcopy(expected)
        observed["calls"][0]["result"]["remote"]["code"] = False
        self.assert_rejected(observed, expected, "$.calls[0].result.remote.code")

    def test_prior_manifest_does_not_alias_zero_bytes_to_false(self):
        with self.assertRaisesRegex(ValueError, "source manifest changed"):
            TRANSPORT.require_stable(
                {"empty": {"bytes": False}}, {"empty": {"bytes": 0}}, "source manifest"
            )

    def test_verified_receipt_is_read_against_native_producer_digest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "episode.json"
            original = receipt()
            raw = json.dumps(original).encode()
            path.write_bytes(raw)
            path.chmod(0o600)
            producer = {"episode": {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}}
            selected = {"episode": original}
            result = TRANSPORT.verify_receipts(root, producer, selected, selected, {})
            self.assertEqual(result["verifiedReceipts"], producer)
            altered = copy.deepcopy(original)
            altered["calls"][0]["attempts"][0]["request"]["chain"] = "chain-B"
            path.write_bytes(json.dumps(altered).encode())
            self.assertEqual(path.stat().st_size, len(raw))
            with self.assertRaisesRegex(ValueError, "native producer and consumed receipt bytes differ: episode"):
                TRANSPORT.verify_receipts(root, producer, selected, selected, {})


def native_log():
    """Minimal valid Go JSONL runtime envelope with one producer receipt."""
    package, parent = "command-line-arguments", "TestCometTransport"
    leaf = parent + "/nil-exact"
    rows = []

    def add(action, test=None, output=None, frame=False):
        row = {"Action": action, "Package": package, "Time": "2026-11-19T12:00:00.5Z"}
        if test is not None:
            row["Test"] = test
        if output is not None:
            row["Output"] = output
        if frame:
            row["OutputType"] = "frame"
        if action == "pass":
            row["Elapsed"] = 0.125
        rows.append(row)

    add("start")
    add("run", parent)
    add("output", parent, "=== RUN   " + parent + "\n", True)
    add("output", parent, "    transport_test.go:91: transport process 7 pid:[8678] 912\n")
    add("run", leaf)
    add("output", leaf, "=== RUN   " + leaf + "\n", True)
    add("output", leaf, "    transport_test.go:112: receipt nil-exact 1 " + "a" * 64 + "\n")
    add("output", leaf, "--- PASS: " + leaf + " (0.125s)\n", True)
    add("pass", leaf)
    add("output", parent, "--- PASS: " + parent + " (0.125s)\n", True)
    add("pass", parent)
    add("output", output="PASS\n", frame=True)
    add("output", output="ok  \tcommand-line-arguments\t0.125s\n")
    add("pass")
    return b"".join(json.dumps(row).encode() + b"\n" for row in rows)


class NativeEnvelopeTest(unittest.TestCase):
    def test_decimal_elapsed_and_exact_producer(self):
        self.assertEqual(
            TRANSPORT.native_outcomes(native_log(), 0, ("nil-exact",)),
            {"process": {"pid": 7, "namespace": "pid:[8678]", "startTicks": "912"},
             "receipts": {"nil-exact": {"bytes": 1, "sha256": "a" * 64}}},
        )

    def test_does_not_treat_trailing_null_as_end_of_stream(self):
        with self.assertRaisesRegex(ValueError, "additional native events"):
            TRANSPORT.native_outcomes(native_log() + b"null\n{}\n", 0, ("nil-exact",))

    def test_rejects_reordered_lifecycle(self):
        rows = native_log().splitlines()
        rows[4], rows[5] = rows[5], rows[4]
        with self.assertRaisesRegex(ValueError, "ordered native event"):
            TRANSPORT.native_outcomes(b"\n".join(rows), 0, ("nil-exact",))


if __name__ == "__main__":
    unittest.main()
