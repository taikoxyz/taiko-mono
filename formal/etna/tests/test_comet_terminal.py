"""Terminal-commit context regressions; native crypto/store checks are separate."""
from copy import deepcopy
import importlib
from pathlib import Path
import sys
import unittest

CONFORMANCE = Path(__file__).resolve().parents[1] / "conformance"
sys.path.insert(0, str(CONFORMANCE))

DOMAIN = "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
OTHER_DOMAIN = "etna-lPNjL_XC1QbJXucXeZN7hTo8cZ-aemx12WQM7raJX6o"
A = dict(hash="aa" * 32, partsTotal=1, partsHash="ab" * 32)
B = dict(hash="bb" * 32, partsTotal=2, partsHash="bc" * 32)
MISSING_REASON = "failed to reconstruct last commit; commit for height 1000 not found"
QUORUM_REASON = "failed to reconstruct last commit; extended commit does not have +2/3 majority"
DOMAIN_REASON = (
    "failed to reconstruct vote set from commit: failed to verify vote with ChainID "
    + OTHER_DOMAIN
    + " and PubKey PubKeySecp256k1eth{03CC8704B8A60A0DEFA3A99A7299F2E9C3FBC395AFB04AC078425EF8A1793CC030}: invalid signature"
)
SLOT_REASON = (
    "failed to reconstruct vote set from commit: vote.ValidatorAddress (D2431CA38735C2FD438E2CAA23F094191D89675B) "
    "does not match address (612B7BE154A64292AAE070AAA86FCD66BA218071) for vote.ValidatorIndex (1)\n"
    "Ensure the genesis file is correct across all validators: invalid validator address"
)


def bound_context(case="terminal-a"):
    """Literal helper input, not evidence of a Go constructor or signed chain."""
    selected = A if case == "terminal-a" else B
    result = "accept" if case == "terminal-a" else "block-id"
    return dict(case=case, chainID=DOMAIN, stateHeight=1000, seenHeight=1000,
                successorHeight=1001, stateParent=deepcopy(A), seenParent=deepcopy(selected),
                majorityParent=deepcopy(selected), constructorAccepted=True,
                verifyResult=result, successorParent=deepcopy(A),
                successorCommitParent=deepcopy(selected), successorResult=result,
                successorSeconds=1700000000, successorNanos=123)


def constructor_context(case):
    data = dict(api="consensus.NewState", accepted=True, panicType="", panicReason="",
                wrappedError="", verificationChain=DOMAIN, signerIndex=0, signatureIndex=0,
                seenPresent=True, fallbackPresent=False, signedPower=3, totalPower=4)
    if case == "missing-commit":
        data.update(accepted=False, panicType="string", panicReason=MISSING_REASON,
                    seenPresent=False, signedPower=0, signatureIndex=-1)
    elif case == "subthreshold":
        data.update(accepted=False, panicType="string", panicReason=QUORUM_REASON,
                    signedPower=2, totalPower=3)
    elif case == "wrong-domain":
        data.update(accepted=False, panicType="*fmt.wrapError", panicReason=DOMAIN_REASON,
                    wrappedError="types.ErrVoteInvalidSignature", verificationChain=OTHER_DOMAIN)
    elif case == "wrong-slot":
        data.update(accepted=False, panicType="*fmt.wrapError", panicReason=SLOT_REASON,
                    wrappedError="types.ErrVoteInvalidValidatorAddress", signatureIndex=1)
    return data


class TerminalContextTest(unittest.TestCase):
    def module(self):
        self.assertTrue((CONFORMANCE / "run_comet_terminal.py").is_file(),
                        "terminal seen-commit consumer is missing")
        return importlib.import_module("run_comet_terminal")

    def test_a_constructor_verifier_and_normal_successor_bind_the_same_parent(self):
        self.assertEqual(self.module()._require_terminal_binding(bound_context()), "bound")

    def test_valid_b_constructor_is_distinct_from_parent_a_authentication(self):
        self.assertEqual(self.module()._require_terminal_binding(bound_context("terminal-b")),
                         "mismatch-refused")

    def test_b_constructor_acceptance_cannot_replace_explicit_commit_verification(self):
        reader = self.module()
        row = bound_context("terminal-b")
        row["verifyResult"] = "accept"
        with self.assertRaises(ValueError):
            reader._require_terminal_binding(row)

    def test_b_normal_successor_must_refuse_at_the_commit_binding(self):
        reader = self.module()
        for result in ("accept", "time", "header-parent", "signature"):
            with self.subTest(result=result), self.assertRaises(ValueError):
                reader._require_terminal_binding(dict(bound_context("terminal-b"), successorResult=result))

    def test_b_successor_header_still_has_parent_a(self):
        reader = self.module()
        row = bound_context("terminal-b")
        row["successorParent"] = deepcopy(B)
        with self.assertRaises(ValueError):
            reader._require_terminal_binding(row)

    def test_reconstructed_b_cannot_be_replaced_by_a_cached_a_commit(self):
        reader = self.module()
        row = bound_context("terminal-b")
        row["successorCommitParent"] = deepcopy(A)
        with self.assertRaises(ValueError):
            reader._require_terminal_binding(row)

    def test_full_part_set_identity_is_bound_even_when_hash_matches(self):
        reader = self.module()
        for field in ("seenParent", "majorityParent", "successorCommitParent"):
            row = bound_context()
            row[field]["partsTotal"] = 2
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_terminal_binding(row)

    def test_heights_and_times_do_not_accept_bool_or_unrelated_successor_context(self):
        reader = self.module()
        for field, value in (("stateHeight", True), ("seenHeight", 999),
                             ("successorHeight", 1000), ("successorSeconds", 1699999999),
                             ("successorNanos", 0), ("constructorAccepted", 1)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_terminal_binding(dict(bound_context(), **{field: value}))

    def test_constructor_panic_expectations_are_exact_and_source_specific(self):
        reader = self.module()
        for case in ("missing-commit", "subthreshold", "wrong-domain", "wrong-slot"):
            with self.subTest(case=case):
                self.assertEqual(reader._require_constructor_outcome(case, constructor_context(case)),
                                 "expected-panic")

    def test_normal_constructor_result_has_no_hidden_panic(self):
        reader = self.module()
        for case in ("terminal-a", "terminal-b"):
            with self.subTest(case=case):
                self.assertEqual(reader._require_constructor_outcome(case, constructor_context(case)), "accept")
        changed = constructor_context("terminal-a")
        changed["panicType"] = "string"
        changed["panicReason"] = MISSING_REASON
        with self.assertRaises(ValueError):
            reader._require_constructor_outcome("terminal-a", changed)

    def test_unexpected_panic_type_reason_or_wrong_api_remains_unrecognized(self):
        reader = self.module()
        original = constructor_context("wrong-domain")
        for fields in (dict(panicType="string"), dict(panicReason="invalid signature"),
                       dict(wrappedError="types.ErrVoteInvalidValidatorIndex"),
                       dict(api="VoteSet.MakeExtendedCommit"), dict(accepted=True)):
            with self.subTest(fields=fields), self.assertRaises(ValueError):
                reader._require_constructor_outcome("wrong-domain", dict(original, **fields))

    def test_missing_constructor_case_requires_both_commit_sources_absent(self):
        reader = self.module()
        for field in ("seenPresent", "fallbackPresent"):
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_constructor_outcome("missing-commit",
                                                   dict(constructor_context("missing-commit"), **{field: True}))

    def test_equal_refusal_labels_cannot_hide_domain_slot_or_weight_aliases(self):
        reader = self.module()
        changes = (("wrong-domain", dict(verificationChain=DOMAIN)),
                   ("wrong-slot", dict(signatureIndex=0)),
                   ("subthreshold", dict(signedPower=3)),
                   ("subthreshold", dict(totalPower=4)))
        for case, fields in changes:
            with self.subTest(case=case, fields=fields), self.assertRaises(ValueError):
                reader._require_constructor_outcome(case, dict(constructor_context(case), **fields))

    def test_closed_contexts_preserve_json_integer_boolean_identity(self):
        reader = self.module()
        for field, value in (("signerIndex", False), ("signatureIndex", True),
                             ("signedPower", True), ("totalPower", 4.0),
                             ("accepted", 0), ("seenPresent", 1), ("fallbackPresent", 0)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                reader._require_constructor_outcome("terminal-a",
                                                   dict(constructor_context("terminal-a"), **{field: value}))
        for case in ("terminal-a", "wrong-domain"):
            with self.subTest(case=case), self.assertRaises(ValueError):
                reader._require_constructor_outcome(case, dict(constructor_context(case), extra="unrelated"))

class TerminalOperationalTest(unittest.TestCase):
    """Transport/metadata regressions; synthetic events are not native evidence."""
    def common(self):
        return importlib.import_module("comet_boundary_common")

    def test_producer_elapsed_metadata_roundtrips_without_protocol_number_coercion(self):
        import json
        common = self.common()
        value = {"seconds": 0.125, "returncode": 0, "timedOut": False,
                 "reports": [{"seconds": 0.25, "height": 1000}]}
        try:
            result = common.metadata_json(json.dumps(value).encode())
        except ValueError as error:
            self.fail("actual producer metadata cannot roundtrip: " + str(error))
        self.assertEqual(result, value)
        self.assertIs(type(result["seconds"]), float)
        self.assertIs(type(result["reports"][0]["height"]), int)
        self.assertIs(type(result["timedOut"]), bool)

    def test_metadata_decoder_refuses_duplicates_and_all_nonfinite_numbers(self):
        common = self.common()
        for raw in (b'{"seconds":0.5,"seconds":1}', b'{"seconds":NaN}',
                    b'{"seconds":Infinity}', b'{"seconds":-Infinity}', b'{"seconds":1e9999}'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                common.metadata_json(raw)

    def stream(self, case="terminal-a"):
        import json
        common = self.common()
        parent, package = "TestTerminalSeenCommit", "example.org/etna-comet-boundary"
        receipt = json.dumps({"case": case, "payload": "a" * 2400}, separators=(",", ":")).encode()
        received = []
        def audit(raw, *, source_fault):
            self.assertFalse(source_fault)
            if raw != receipt:
                raise ValueError("changed raw receipt supplied to the auditor")
            received.append(raw)
            return {"case": case}
        profile = common.BoundaryProfile("terminal-seen-commit", "comet_boundary", package,
                    parent, case, (case,), (), audit, "types/validation.go", b"before", b"after", case, ())
        rows = []
        def event(action, test=None, output=None, kind=None):
            row = {"Package": package, "Action": action}
            if test is not None: row["Test"] = test
            if output is not None: row["Output"] = output
            if kind is not None: row["OutputType"] = kind
            rows.append(row)
        test = parent + "/" + case
        event("start")
        for identity in (parent, test):
            event("run", identity)
            event("output", identity, "=== RUN   " + identity + "\n", "frame")
        text = "    terminal_test.go:1: receipt=" + receipt.decode() + "\n"
        for at in range(0, len(text), 1024): event("output", test, text[at:at+1024])
        for identity in (test, parent):
            event("output", identity, "--- PASS: " + identity + " (0.00s)\n", "frame")
            event("pass", identity)
        event("output", output="PASS\n", kind="frame")
        event("output", output="ok  \t" + package + "\t0.001s\n")
        event("pass")
        return profile, rows, received, json

    def test_current_go_frame_types_and_split_receipt_deliver_exact_original_bytes(self):
        common = self.common()
        profile, rows, received, json = self.stream()
        raw = b"\n".join(json.dumps(row).encode() for row in rows) + b"\n"
        try:
            result = common.collect(profile, raw, 0, "smoke")
        except ValueError as error:
            self.fail("valid current-Go receipt framing refused: " + str(error))
        self.assertEqual(list(result), ["terminal-a"])
        self.assertEqual(len(received), 1)

    def test_missing_receipt_fragment_wrong_output_type_and_extra_event_are_refused(self):
        common = self.common()
        for change in ("fragment", "type", "extra"):
            profile, rows, _, json = self.stream()
            if change == "fragment": del rows[6]
            elif change == "type": rows[2]["OutputType"] = "error"
            else: rows.append(dict(rows[-1]))
            raw = b"\n".join(json.dumps(row).encode() for row in rows) + b"\n"
            with self.subTest(change=change), self.assertRaises(ValueError):
                common.collect(profile, raw, 0, "smoke")

    def test_mutant_diagnostics_precede_receipt_as_the_actual_go_producer_logs_them(self):
        common = self.common()
        profile, rows, _, json = self.stream("terminal-b")
        messages = (
            "terminal-binding id=terminal-b api=VerifyCommit expected=block-id got=accept",
            "terminal-binding id=terminal-b api=ValidateBlock expected=block-id got=accept",
        )
        def audit(raw, *, source_fault):
            self.assertTrue(source_fault)
            self.assertEqual(json.loads(raw)["case"], "terminal-b")
            return {"case": "terminal-b"}
        profile = profile._replace(audit=audit, fault_diagnostics=messages)
        test = profile.parent + "/terminal-b"
        diagnostics = [dict(Package=profile.package, Action="output", Test=test, OutputType="error",
                            Output="    terminal_test.go:284: " + message + "\n") for message in messages]
        rows[5:5] = diagnostics
        for row in rows:
            if row["Action"] == "pass": row["Action"] = "fail"
            if row.get("Output", "").startswith("--- PASS:"): row["Output"] = row["Output"].replace("--- PASS:", "--- FAIL:", 1)
            if row.get("Output") == "PASS\n": row["Output"] = "FAIL\n"
            if row.get("Output", "").startswith("ok  \t"):
                row["Output"] = "FAIL\t" + profile.package + "\t0.001s\n"
                row["OutputType"] = "frame"
        raw = b"\n".join(json.dumps(row).encode() for row in rows) + b"\n"
        try:
            result = common.collect(profile, raw, 1, "mutant")
        except ValueError as error:
            self.fail("actual producer diagnostic order refused: " + str(error))
        self.assertEqual(list(result), ["terminal-b"])
        for change in ("receipt-first", "duplicate", "wrong-diagnostic"):
            changed = [dict(row) for row in rows]
            if change == "receipt-first":
                moved = changed[5:7]
                del changed[5:7]
                at = next(i for i, row in enumerate(changed) if row.get("Output", "").startswith("--- FAIL:"))
                changed[at:at] = moved
            elif change == "duplicate":
                changed.insert(5, dict(changed[5]))
            else:
                changed[5]["Output"] = changed[5]["Output"].replace("api=VerifyCommit", "api=Other")
            altered = b"\n".join(json.dumps(row).encode() for row in changed) + b"\n"
            with self.subTest(change=change), self.assertRaises(ValueError):
                common.collect(profile, altered, 1, "mutant")


if __name__ == "__main__":
    unittest.main()
