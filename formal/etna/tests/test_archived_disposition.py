"""Exercise the archived-disposition CLI on a disposable source export."""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]
MANIFEST = "archived_disposition.json"
CHECKER = "check_archived_disposition.py"
RAW_FI = "experiments/fi-raw/configs/fi-mixed.cfg"
PROJECTED_FI = "experiments/fi-projected/configs/fi-mixed.cfg"
BUDGET_FI = "experiments/fi-budget/configs/fi-mixed.cfg"
FI_BASE = "experiments/fi-base/EtnaSettlement.tla"
ROLLBACK_BASE = "experiments/m09-wide-runtime/EtnaSettlement.tla"
SIGNER_CFG = "experiments/signer-wide-two-payloads.cfg"
SIGNER_NIL_CFG = "experiments/signer-wide-three-payloads.cfg"
ROLLBACK_CFG = "experiments/m09-wide-runtime/configs/rollback-replay.cfg"
RAW_REGISTRY = "experiments/registry-raw-init/registry-workflow.cfg"
BUDGET_NOTE = "experiments/fi-budget/OBSERVATION.md"
GUIDE = "ARCHIVED_DISPOSITION.md"
N04_EVIDENCE = "REPORT.md#n04-actual-late-token-failures-and-identical-retries"


class ArchivedDispositionTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name) / "etna"
        shutil.copytree(SOURCE / "experiments", self.root / "experiments")
        (self.root / "conformance").mkdir()
        for path in (*SOURCE.glob("*.md"), *(SOURCE / "conformance").glob("*.md")):
            shutil.copyfile(path, self.root / path.relative_to(SOURCE))
        for name in (MANIFEST, CHECKER, "EtnaSignerCrash.tla"):
            if (SOURCE / name).is_file():
                shutil.copyfile(SOURCE / name, self.root / name)

    def read_manifest(self):
        return json.loads((self.root / MANIFEST).read_text(encoding="utf-8"))

    def write_manifest(self, manifest):
        (self.root / MANIFEST).write_text(json.dumps(manifest), encoding="utf-8")

    def row(self, manifest, config):
        return next(row for row in manifest["rows"] if row["config"] == config)

    def check(self):
        return subprocess.run(
            [sys.executable, str(self.root / CHECKER)],
            cwd=self.root.parent,
            capture_output=True,
            text=True,
            check=False,
            timeout=15,
        )

    def assert_rejected(self, message):
        result = self.check()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(message, result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_accepts_the_complete_export_without_writing_files(self):
        snapshot = {
            path: path.read_bytes() for path in self.root.rglob("*") if path.is_file()
        }
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("19 INCONCLUSIVE", result.stdout)
        self.assertEqual(
            snapshot,
            {path: path.read_bytes() for path in self.root.rglob("*") if path.is_file()},
        )

    def test_missing_row_is_detected_from_config_inventory(self):
        manifest = self.read_manifest()
        manifest["rows"].remove(self.row(manifest, RAW_FI))
        self.write_manifest(manifest)
        self.assert_rejected("missing disposition: " + RAW_FI)

    def test_extra_row_is_rejected(self):
        manifest = self.read_manifest()
        extra = dict(self.row(manifest, RAW_FI), config="experiments/extra.cfg")
        manifest["rows"].append(extra)
        self.write_manifest(manifest)
        self.assert_rejected("extra disposition: experiments/extra.cfg")

    def test_duplicate_row_is_rejected_even_when_total_stays_constant(self):
        manifest = self.read_manifest()
        manifest["rows"].remove(self.row(manifest, RAW_FI))
        manifest["rows"].append(self.row(manifest, PROJECTED_FI))
        self.write_manifest(manifest)
        self.assert_rejected("duplicate disposition: " + PROJECTED_FI)

    def test_extra_config_is_discovered_even_without_a_row(self):
        shutil.copyfile(self.root / RAW_FI, self.root / "experiments/added.cfg")
        self.assert_rejected("missing disposition: experiments/added.cfg")

    def test_missing_config_and_row_do_not_shrink_audited_cohort(self):
        manifest = self.read_manifest()
        manifest["rows"].remove(self.row(manifest, RAW_FI))
        (self.root / RAW_FI).unlink()
        self.write_manifest(manifest)
        self.assert_rejected("expected 19 archived configurations")

    def test_changed_config_is_rejected(self):
        path = self.root / RAW_FI
        path.write_bytes(path.read_bytes().replace(b"MaxTime = 2", b"MaxTime = 3"))
        self.assert_rejected("config SHA-256 mismatch: " + RAW_FI)

    def test_retained_configs_cannot_be_rebound_by_rehashing_the_manifest(self):
        changes = (
            (SIGNER_CFG, b"MaxSlot = 2", b"MaxSlot = 3"),
            (ROLLBACK_CFG, b"MaxTime = 1", b"MaxTime = 2"),
        )
        manifest = self.read_manifest()
        for config, old, new in changes:
            with self.subTest(config=config):
                path = self.root / config
                baseline = path.read_bytes()
                replacement = baseline.replace(old, new)
                self.assertNotEqual(baseline, replacement)
                path.write_bytes(replacement)
                changed = self.row(manifest, config)
                baseline_digest = changed["config_sha256"]
                changed["config_sha256"] = hashlib.sha256(replacement).hexdigest()
                self.write_manifest(manifest)
                try:
                    self.assert_rejected("retained config SHA-256 mismatch: " + config)
                finally:
                    path.write_bytes(baseline)
                    changed["config_sha256"] = baseline_digest

    def test_the_signer_nil_profile_cannot_be_replaced_by_the_two_payload_profile(self):
        replacement = (self.root / SIGNER_CFG).read_bytes()
        (self.root / SIGNER_NIL_CFG).write_bytes(replacement)
        manifest = self.read_manifest()
        self.row(manifest, SIGNER_NIL_CFG)["config_sha256"] = hashlib.sha256(replacement).hexdigest()
        self.write_manifest(manifest)
        self.assert_rejected("retained config SHA-256 mismatch: " + SIGNER_NIL_CFG)

    def test_same_config_bytes_cannot_move_out_of_audited_archive_layout(self):
        moves = (
            (SIGNER_CFG, SIGNER_CFG.replace("two-payloads", "unreviewed"), "unreviewed retained config"),
            (RAW_REGISTRY, RAW_REGISTRY.replace("/registry-workflow.cfg", "/configs/registry-workflow.cfg"), "config layout"),
            (RAW_FI, RAW_FI.replace("/configs", ""), "config layout"),
            (ROLLBACK_CFG, ROLLBACK_CFG.replace("/configs", ""), "config layout"),
        )
        manifest = self.read_manifest()
        for old, new, diagnostic in moves:
            with self.subTest(config=old):
                target = self.root / new
                target.parent.mkdir(parents=True, exist_ok=True)
                source = self.root / old
                source.rename(target)
                changed = self.row(manifest, old)
                changed["config"] = new
                self.write_manifest(manifest)
                try:
                    self.assert_rejected(diagnostic)
                finally:
                    target.rename(source)
                    changed["config"] = old

    def test_registry_directory_name_cannot_be_rebound_with_unchanged_inputs(self):
        old = "experiments/registry-raw-init"
        new = "experiments/registry-unreviewed"
        (self.root / old).rename(self.root / new)
        manifest = (self.root / MANIFEST).read_text(encoding="utf-8")
        (self.root / MANIFEST).write_text(manifest.replace(old, new), encoding="utf-8")
        self.assert_rejected("unreviewed archive for config:")

    def test_registry_note_does_not_accept_a_full_filename_as_a_stem(self):
        renamed = RAW_REGISTRY + ".cfg"
        (self.root / RAW_REGISTRY).rename(self.root / renamed)
        manifest = self.read_manifest()
        self.row(manifest, RAW_REGISTRY)["config"] = renamed
        self.write_manifest(manifest)
        guide = self.root / GUIDE
        original = guide.read_text(encoding="utf-8")
        self.assertIn(f"({RAW_REGISTRY})", original)
        guide.write_text(
            original.replace(f"({RAW_REGISTRY})", f"({renamed})"), encoding="utf-8"
        )
        self.assert_rejected("historical observation disagrees with config SHA-256: " + renamed)

    def test_guide_cannot_drop_an_exact_config_link(self):
        path = self.root / GUIDE
        original = path.read_text(encoding="utf-8")
        path.write_text(original.replace(f"({RAW_FI})", f"({BUDGET_FI})"), encoding="utf-8")
        self.assert_rejected("guide config links must match the 19 archived configs")

    def test_immutable_observation_preserves_the_wrapper_and_base_roles(self):
        path = self.root / BUDGET_NOTE
        original = path.read_text(encoding="utf-8")
        manifest = self.read_manifest()
        wrapper = manifest["source_sha256"]["experiments/fi-budget/EtnaForcedInclusion.tla"]
        base = manifest["source_sha256"][FI_BASE]
        changed = original.replace(wrapper, "DIGEST_PLACEHOLDER").replace(base, wrapper)
        path.write_text(changed.replace("DIGEST_PLACEHOLDER", base), encoding="utf-8")
        self.assert_rejected("historical observation SHA-256 mismatch: " + BUDGET_NOTE)

    def test_one_profile_cannot_be_marked_pass_in_its_historical_observation(self):
        path = self.root / BUDGET_NOTE
        original = path.read_text(encoding="utf-8")
        changed = original.replace("- `fi-mixed`: **INCONCLUSIVE**", "- `fi-mixed`: **PASS**")
        self.assertNotEqual(original, changed)
        path.write_text(changed, encoding="utf-8")
        self.assert_rejected("historical observation SHA-256 mismatch: " + BUDGET_NOTE)

    def test_fi_base_observation_is_part_of_historical_evidence(self):
        note = "experiments/fi-base/OBSERVATION.md"
        with (self.root / note).open("a", encoding="utf-8") as stream:
            stream.write("\nSubstituted dependency documentation.\n")
        self.assert_rejected("historical observation SHA-256 mismatch: " + note)

    def test_same_config_bytes_cannot_select_a_different_version(self):
        self.assertEqual(
            (self.root / PROJECTED_FI).read_bytes(), (self.root / BUDGET_FI).read_bytes()
        )
        manifest = self.read_manifest()
        self.row(manifest, PROJECTED_FI)["sources"] = self.row(manifest, BUDGET_FI)["sources"]
        self.write_manifest(manifest)
        self.assert_rejected("historical source association mismatch: " + PROJECTED_FI)

    def test_fi_requires_its_transitive_settlement_model(self):
        manifest = self.read_manifest()
        self.row(manifest, PROJECTED_FI)["sources"].remove(FI_BASE)
        self.write_manifest(manifest)
        self.assert_rejected("historical source association mismatch: " + PROJECTED_FI)

    def test_changed_fi_base_cannot_be_rebound_by_rehashing_the_manifest(self):
        path = self.root / FI_BASE
        replacement = path.read_bytes() + b"\n"
        path.write_bytes(replacement)
        manifest = self.read_manifest()
        manifest["source_sha256"][FI_BASE] = hashlib.sha256(replacement).hexdigest()
        self.write_manifest(manifest)
        self.assert_rejected("historical observation disagrees with SHA-256: " + FI_BASE)

    def test_rollback_requires_its_own_identical_settlement_copy(self):
        self.assertEqual(
            (self.root / FI_BASE).read_bytes(), (self.root / ROLLBACK_BASE).read_bytes()
        )
        config = "experiments/m09-wide-runtime/configs/rollback-replay.cfg"
        manifest = self.read_manifest()
        self.row(manifest, config)["sources"][1] = FI_BASE
        self.write_manifest(manifest)
        self.assert_rejected("historical source association mismatch: " + config)

    def test_changed_wrapper_cannot_be_rebound_to_another_fi_version(self):
        target = "experiments/fi-budget/EtnaForcedInclusion.tla"
        replacement = (self.root / "experiments/fi-projected/EtnaForcedInclusion.tla").read_bytes()
        (self.root / target).write_bytes(replacement)
        manifest = self.read_manifest()
        manifest["source_sha256"][target] = hashlib.sha256(replacement).hexdigest()
        self.write_manifest(manifest)
        self.assert_rejected("historical observation disagrees with SHA-256: " + target)

    def test_changed_rollback_base_is_rejected(self):
        path = self.root / ROLLBACK_BASE
        path.write_bytes(path.read_bytes() + b"\n")
        self.assert_rejected("source SHA-256 mismatch: " + ROLLBACK_BASE)

    def test_signer_predecessor_identity_cannot_be_rebound_to_local_bytes(self):
        manifest = self.read_manifest()
        manifest["signer_predecessor_sha256"] = manifest["source_sha256"]["EtnaSignerCrash.tla"]
        self.write_manifest(manifest)
        self.assert_rejected("signer predecessor attestation mismatch")

    def test_signer_local_source_cannot_be_claimed_as_historical_run_input(self):
        manifest = self.read_manifest()
        self.row(manifest, SIGNER_CFG)["run_source"] = "archived_bytes"
        self.write_manifest(manifest)
        self.assert_rejected("historical run source mismatch: " + SIGNER_CFG)

    def test_a_result_cannot_be_promoted_to_pass(self):
        manifest = self.read_manifest()
        self.row(manifest, RAW_FI)["status"] = "PASS"
        self.write_manifest(manifest)
        self.assert_rejected("expected INCONCLUSIVE: " + RAW_FI)

    def test_missing_required_evidence_anchor_is_rejected(self):
        report = self.root / "REPORT.md"
        report.write_text(
            report.read_text(encoding="utf-8").replace(
                "## N04 actual late token failures and identical retries", "## Replaced N04"
            ),
            encoding="utf-8",
        )
        self.assert_rejected("evidence anchor missing: " + N04_EVIDENCE)

    def test_existing_but_unrelated_evidence_cannot_replace_n04(self):
        manifest = self.read_manifest()
        evidence = manifest["evidence"]["R01"]
        evidence["REPORT.md#n03-actual-exit-withdrawal-and-slot-reuse"] = evidence.pop(
            N04_EVIDENCE
        )
        self.write_manifest(manifest)
        self.assert_rejected("required evidence missing: " + N04_EVIDENCE)

    def test_publication_docs_can_be_updated_without_repinning_bytes(self):
        for name in ("REPORT.md", "WORKLIST.md", "README.md"):
            with (self.root / name).open("a", encoding="utf-8") as stream:
                stream.write("\n## N05 disposition publication\n\nPublication update.\n")
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_closed_schema_rejects_duplicate_json_members(self):
        path = self.root / MANIFEST
        content = path.read_text(encoding="utf-8")
        path.write_text(content.replace("{", '{"schema_version": 1,', 1), encoding="utf-8")
        self.assert_rejected("duplicate JSON member: schema_version")

    def test_closed_schema_rejects_unknown_row_fields(self):
        manifest = self.read_manifest()
        self.row(manifest, RAW_FI)["completed"] = True
        self.write_manifest(manifest)
        self.assert_rejected("unexpected keys in " + RAW_FI + ": completed")

    def test_remaining_obligation_must_stay_open_or_waiting(self):
        worklist = self.root / "WORKLIST.md"
        before = worklist.read_text(encoding="utf-8")
        for status in (
            "COMPLETE", "COMPLETE / WAITING", "WAITING-COMPLETE",
            "WAITING/COMPLETE", "WAITING / COMPLETE", "WAITING,COMPLETE",
            "WAITING, COMPLETE", "WAITING.CLOSED", "WAITING - COMPLETE",
        ):
            with self.subTest(status=status):
                after = before.replace(
                    "| F01 | M06 + M01 + M07 / WAITING STF",
                    f"| F01 | M06 + M01 + M07 / {status}",
                )
                self.assertNotEqual(before, after)
                worklist.write_text(after, encoding="utf-8")
                self.assert_rejected("obligation F01 must remain OPEN or WAITING")


if __name__ == "__main__":
    unittest.main()
