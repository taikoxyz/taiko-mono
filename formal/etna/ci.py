#!/usr/bin/env python3
"""Require fresh, complete Etna TLC outcomes and the stdlib Python suites.

Tools are provided by the caller. This gate downloads nothing and delegates TLC
classification to check.py, including expected invariant failures.
"""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


TLC_SHA256 = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
PYTHON_SUITE = (
    "import json,sys,unittest\n"
    "from pathlib import Path\n"
    "suite=unittest.defaultTestLoader.discover(sys.argv[1])\n"
    "discovered=suite.countTestCases()\n"
    "result=unittest.TextTestRunner(verbosity=2).run(suite)\n"
    "counts=dict(discovered=discovered,run=result.testsRun,skipped=len(result.skipped),"
    "errors=len(result.errors),failures=len(result.failures),successful=result.wasSuccessful())\n"
    "Path(sys.argv[2]).write_text(json.dumps(counts)+'\\n')\n"
    "print('CI test counts:',counts,flush=True)\n"
    "sys.exit(0 if result.wasSuccessful() and discovered == result.testsRun "
    "and discovered > 0 and not result.skipped else 1)\n"
)
SPEC = importlib.util.spec_from_file_location("etna_check", Path(__file__).with_name("check.py"))
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


def run_child(name, command, root, output, timeout):
    """Persist output and status, and terminate the child group on timeout."""
    started = time.monotonic()
    log = name + ".log"
    with (output / log).open("wb") as stream:
        try:
            process = subprocess.Popen(
                command, cwd=root, stdout=stream, stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL, start_new_session=True,
                env={"PATH": os.environ.get("PATH", os.defpath), "LANG": "C.UTF-8"},
            )
            try:
                returncode = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                stream.write(b"\nCI CHILD TIMEOUT\n")
                returncode = None
            except BaseException:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                raise
        except OSError as error:
            stream.write(str(error).encode())
            returncode = None
    return dict(name=name, command=command, returncode=returncode, log=log,
                seconds=round(time.monotonic() - started, 3))


def verify_results(root, output, configs, snapshot):
    """Audit the existing check.py schema against the discovered input set."""
    files = list((output / "tlc").glob("etna-tlc-*/results.json"))
    if len(files) != 1:
        raise ValueError("need exactly one fresh TLC results.json")
    rows = json.loads(files[0].read_text())
    names = sorted(path.stem for path in configs)
    if (not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows)
            or len(rows) != len(names) or sorted(row.get("case", "") for row in rows) != names):
        raise ValueError("TLC coverage must contain every discovered configuration exactly once")
    by_name = {row["case"]: row for row in rows}
    source_hashes = {path.name: digest for path, digest in snapshot.items() if path.suffix == ".tla"}
    for config in configs:
        row = by_name[config.stem]
        expected = CHECK.parse_expectation(config.read_text())
        module = CHECK.resolve_module(config.read_text(), root)
        if (row.get("expected") != expected or row.get("module") != module.stem
                or row.get("module_sha256") != snapshot[module]
                or row.get("config_sha256") != snapshot[config]
                or row.get("source_sha256") != source_hashes
                or row.get("inputs_unchanged") is not True or row.get("ok") is not True):
            raise ValueError(f"{config.stem}: TLC result/input metadata mismatch")
        if row.get("log") != config.stem + "/tlc.log":
            raise ValueError(f"{config.stem}: unexpected TLC log path")
        log = (files[0].parent / row["log"]).read_text()
        if (not CHECK.classify_output(row.get("returncode"), log, expected)
                or row.get("states") != CHECK.state_counts(log)):
            raise ValueError(f"{config.stem}: exact TLC outcome does not match its log")
    return str(files[0].relative_to(output))


def run_gate(root, java, jar, output):
    root, jar, output = root.resolve(), jar.resolve(), output.resolve()
    # Refuse all pre-existing output, even empty directories. Old results must
    # never stand in for a child that failed to produce a fresh result.
    output.mkdir(parents=True, exist_ok=False)
    summary = dict(ok=False, cases=[], children=[], errors=[])
    try:
        configs = sorted((root / "configs").glob("*.cfg"))
        if not configs:
            raise ValueError("no default configurations found")
        summary["cases"] = [path.stem for path in configs]
        snapshot = CHECK.snapshot_inputs([*configs, *root.glob("*.tla"), jar])
        summary["tlc_sha256"] = snapshot[jar]
        if snapshot[jar] != TLC_SHA256:
            raise ValueError("TLC jar SHA256 does not match the pinned release1.7.4 tool")
        for config in configs:
            CHECK.parse_expectation(config.read_text())
            CHECK.resolve_module(config.read_text(), root)
        summary["input_sha256"] = {
            str(path.relative_to(root)): digest for path, digest in snapshot.items() if path != jar
        }
        commands = [("tlc", [sys.executable, "-B", str(root / "check.py"),
                             "--java", java, "--tlc-jar", str(jar),
                             "--output-dir", str(output / "tlc")], 1800)]
        commands += [(name, [sys.executable, "-B", "-c", PYTHON_SUITE, suite,
                                str(output / (name + "-tests.json"))], 120)
                     for name, suite in (("python", "tests"), ("conformance", "conformance/tests"),
                                         ("sensitivity", "sensitivity/tests"))]
        commands.append(("rules", [sys.executable, "-B", str(
            root.parents[1] / "packages/protocol/docs/etna/rules/tools/check.py")], 120))
        for name, command, timeout in commands:
            child = run_child(name, command, root, output, timeout)
            summary["children"].append(child)
            if name in ("python", "conformance", "sensitivity"):
                try:
                    counts = json.loads((output / (name + "-tests.json")).read_text())
                    child["tests"] = counts
                    if (not isinstance(counts, dict)
                            or any(type(counts.get(key)) is not int for key in
                                   ("discovered", "run", "skipped", "errors", "failures"))
                            or counts["discovered"] <= 0 or counts["run"] != counts["discovered"]
                            or counts["skipped"] != 0 or counts["errors"] != 0
                            or counts["failures"] != 0 or counts.get("successful") is not True):
                        raise ValueError("nonempty, complete, successful suites with zero skips required")
                except (OSError, ValueError, TypeError) as error:
                    summary["errors"].append(f"{name}: invalid Python test counts: {error}")
            print(f"{name}: returncode={child['returncode']} log={output / child['log']}", flush=True)
            if child["returncode"] != 0:
                summary["errors"].append(f"required child failed: {name}")
        summary["results"] = verify_results(root, output, configs, snapshot)
        if (not CHECK.inputs_unchanged(snapshot)
                or sorted((root / "configs").glob("*.cfg")) != configs
                or {path for path in root.glob("*.tla")} != {p for p in snapshot if p.suffix == ".tla"}):
            raise ValueError("model/configuration/tool inputs changed during the CI gate")
    except (OSError, ValueError, TypeError, KeyError) as error:
        summary["errors"].append(str(error))
    summary["ok"] = not summary["errors"]
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"ok": summary["ok"], "errors": summary["errors"],
                      "summary": str(output / "summary.json")}), flush=True)
    return 0 if summary["ok"] else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", default="java", help="Java 17+ executable")
    parser.add_argument("--tlc-jar", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True, help="must not already exist")
    args = parser.parse_args(argv)
    try:
        return run_gate(Path(__file__).resolve().parent, args.java, args.tlc_jar, args.output_dir)
    except OSError as error:
        parser.error(str(error))


if __name__ == "__main__":
    sys.exit(main())
