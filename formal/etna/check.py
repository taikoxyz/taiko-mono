#!/usr/bin/env python3
"""Run the Etna TLC suite and require each configuration's exact outcome.

Tools are supplied by the caller; this script downloads nothing. TLC databases
and logs go only under the explicitly selected output directory.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


EXPECTATION = re.compile(
    r"^\\\* EXPECT: (PASS|INVARIANT ([A-Za-z_][A-Za-z_0-9]*))[ \t]*$", re.MULTILINE
)
VIOLATED = re.compile(r"^Error: Invariant ([A-Za-z_][A-Za-z_0-9]*) is violated\.$", re.MULTILINE)
STATS = re.compile(
    r"([\d,]+) states generated, ([\d,]+) distinct states found, "
    r"([\d,]+) states left on queue\."
)


def parse_expectation(text):
    matches = list(EXPECTATION.finditer(text))
    if len(matches) != 1:
        raise ValueError("configuration needs exactly one EXPECT comment")
    return "PASS" if matches[0].group(1) == "PASS" else matches[0].group(2)


def state_counts(output):
    matches = list(STATS.finditer(output))
    if not matches:
        return None
    return dict(zip(
        ("generated", "distinct", "queued"),
        (int(value.replace(",", "")) for value in matches[-1].groups()),
    ))


def classify_output(returncode, output, expected):
    """A timeout, parse error or wrong violation must never count as success."""
    counts = state_counts(output)
    if expected == "PASS":
        return (
            returncode == 0
            and "Model checking completed. No error has been found." in output
            and re.search(r"^Error:", output, re.MULTILINE) is None
            and counts is not None
            and counts["queued"] == 0
        )
    return (
        returncode == 12
        and VIOLATED.findall(output) == [expected]
        and counts is not None
        and re.search(r"^Error:.*(?:exception|parsing|semantic)", output, re.MULTILINE | re.IGNORECASE) is None
    )


def positive_int(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def parse_module(text):
    declarations = [
        line.strip() for line in text.splitlines()
        if re.match(r"^\s*\\\*\s*MODULE\b", line)
    ]
    if not declarations:
        return "EtnaSettlement"
    if len(declarations) != 1:
        raise ValueError("configuration permits only one MODULE comment")
    match = re.fullmatch(r"\\\* MODULE: ([A-Za-z_][A-Za-z_0-9]*)", declarations[0])
    if match is None:
        raise ValueError("MODULE must be a local TLA+ module identifier")
    return match.group(1)


def resolve_module(text, root):
    module = root / (parse_module(text) + ".tla")
    if not module.is_file() or module.resolve().parent != root.resolve():
        raise ValueError("selected MODULE must exist as a local TLA+ file")
    return module


def snapshot_inputs(paths):
    return {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}


def inputs_unchanged(snapshot):
    try:
        return snapshot_inputs(snapshot) == snapshot
    except OSError:
        return False


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", default="java", help="Java 17+ executable")
    parser.add_argument("--tlc-jar", required=True, type=Path, help="official tla2tools.jar")
    parser.add_argument("--output-dir", required=True, type=Path, help="parent for unique run directories")
    parser.add_argument("--case", action="append", help="configuration stem; repeat to select cases")
    parser.add_argument("--timeout", type=positive_int, default=45, help="seconds per configuration")
    parser.add_argument("--heap-mb", type=positive_int, default=512)
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parent
    jar = args.tlc_jar.resolve()
    if not jar.is_file():
        parser.error("--tlc-jar must name an existing file")
    configs = sorted((root / "configs").glob("*.cfg"))
    if args.case:
        selected = set(args.case)
        unknown = selected - {path.stem for path in configs}
        if unknown:
            parser.error("unknown cases: " + ", ".join(sorted(unknown)))
        configs = [path for path in configs if path.stem in selected]
    if not configs:
        parser.error("no configurations found")
    try:
        snapshot = snapshot_inputs([*configs, *root.glob("*.tla"), jar])
        expected = {path.stem: parse_expectation(path.read_text()) for path in configs}
        modules = {path.stem: resolve_module(path.read_text(), root) for path in configs}
    except (ValueError, OSError) as error:
        parser.error(str(error))
    if not inputs_unchanged(snapshot):
        parser.error("model/configuration changed while preparing the run")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    run_dir = Path(tempfile.mkdtemp(prefix="etna-tlc-", dir=args.output_dir))
    results = []
    for config in configs:
        case_dir = run_dir / config.stem
        case_dir.mkdir()
        command = [
            args.java, f"-Xmx{args.heap_mb}m", "-XX:+UseParallelGC", "-cp", str(jar),
            "tlc2.TLC", "-workers", "1", "-seed", "1", "-deadlock",
            "-metadir", str(case_dir / "states"), "-config", str(config),
            str(modules[config.stem]),
        ]
        start = time.monotonic()
        try:
            completed = subprocess.run(
                command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                timeout=args.timeout, check=False,
                env={"PATH": os.environ.get("PATH", os.defpath), "LANG": "C.UTF-8"},
            )
            output = completed.stdout.decode(errors="replace")
            returncode = completed.returncode
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b"").decode(errors="replace") + "\nCHECKER TIMEOUT\n"
            returncode = None
        except OSError as error:
            output = str(error)
            returncode = None
        unchanged = inputs_unchanged(snapshot)
        if not unchanged:
            output += "\nCHECKER INPUT CHANGED: discard this run and retry a stable candidate.\n"
        (case_dir / "tlc.log").write_text(output)
        ok = unchanged and classify_output(returncode, output, expected[config.stem])
        result = {
            "case": config.stem, "expected": expected[config.stem], "ok": ok,
            "module": modules[config.stem].stem,
            "module_sha256": snapshot[modules[config.stem]],
            "config_sha256": snapshot[config],
            "inputs_unchanged": unchanged,
            "source_sha256": {path.name: digest for path, digest in snapshot.items()
                              if path.suffix == ".tla"},
            "returncode": returncode, "seconds": round(time.monotonic() - start, 3),
            "states": state_counts(output), "log": f"{config.stem}/tlc.log",
        }
        results.append(result)
        print(f"{'PASS' if ok else 'FAIL'} {config.stem}: expected {expected[config.stem]}", flush=True)
        if not ok:
            print(output[-4000:], flush=True)
        # Counterexample text remains in tlc.log; generated state databases are disposable.
        shutil.rmtree(case_dir / "states", ignore_errors=True)
        if not unchanged:
            break
    (run_dir / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"Results: {run_dir / 'results.json'}")
    return 0 if all(result["ok"] for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
