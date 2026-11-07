#!/usr/bin/env python3
"""Measure complete signed windows through Rust authentication and the pinned stock stores."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
TEST = "test_utils::consensus_mpt::import_resources::signed_checkpoint_resource_phase"


def disk(root):
    logical = allocated = 0
    for directory, _, files in os.walk(root):
        for name in files:
            try:
                stat = (Path(directory) / name).stat()
            except FileNotFoundError:  # Concurrent compaction and private spool cleanup.
                continue
            logical += stat.st_size
            allocated += stat.st_blocks * 512
    return logical, allocated


def measure(phase, args, directory, env):
    start = time.monotonic()
    peak_disk = list(disk(directory))
    peak_spool = [0, 0]
    with (directory / (phase + ".log")).open("wb") as log:
        proc = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT, env=env)
        try:
            while True:
                peak_disk = list(map(max, zip(peak_disk, disk(directory))))
                peak_spool = list(map(max, zip(peak_spool, disk(directory / "spool"))))
                pid, status, usage = os.wait4(proc.pid, os.WNOHANG)
                if pid:
                    proc.returncode = os.waitstatus_to_exitcode(status)
                    break
                if phase != "generate" and time.monotonic() - start > 600:
                    raise RuntimeError(f"{phase} exceeded the predeclared 600 second limit")
                time.sleep(0.2)
        finally:
            if proc.returncode is None:
                proc.kill()
                proc.wait()
    elapsed = time.monotonic() - start
    if phase != "generate" and elapsed > 600:
        raise RuntimeError(f"{phase} exceeded the predeclared 600 second limit")
    log_text = (directory / (phase + ".log")).read_text()
    if proc.returncode:
        raise RuntimeError(f"{phase} exited {proc.returncode}\n{log_text[-8192:]}")
    rss = usage.ru_maxrss * (1 if sys.platform == "darwin" else 1024)
    result = dict(wall=round(elapsed, 3), user=round(usage.ru_utime, 3),
                  system=round(usage.ru_stime, 3), rss_bytes=rss,
                  sampled_peak_disk_bytes=peak_disk, sampled_peak_spool_bytes=peak_spool)
    print(phase, json.dumps(result), flush=True)
    if phase != "generate" and (rss > 2 * 1024**3 or max(peak_disk) > 4 * 1024**3):
        raise RuntimeError(f"{phase} exceeded its local resource limits")
    return log_text


def binary():
    command = ["cargo", "test", "--locked", "--release", "-p", "lander", "--lib",
               "--no-run", "--message-format=json"]
    build = subprocess.check_output(command, cwd=ROOT, text=True)
    return next(row["executable"] for row in map(json.loads, build.splitlines())
                if row.get("target", {}).get("name") == "lander" and row.get("executable"))


def profile(directory, executable, helper, height, period):
    directory = directory.resolve()
    (directory / "spool").mkdir()
    print(f"height={height} period={period} fixture={directory}", flush=True)
    env = dict(os.environ, ETNA_RESOURCE_DIR=str(directory), ETNA_RESOURCE_HEIGHT=str(height),
               ETNA_RESOURCE_PERIOD=str(period))
    for phase in ("generate", "verify", "boundary-failures"):
        measure(phase, [executable, TEST, "--exact", "--ignored", "--nocapture"],
                directory, dict(env, ETNA_RESOURCE_PHASE=phase))
    v = json.loads((directory / "verified.json").read_text())
    # These anchors come only from successful own-finalized-L1 Rust authentication.
    trust = ["--trusted-el-hash", v["el_hash"], "--trusted-comet-hash", v["comet_hash"],
             "--trusted-val-state-hash", v["val_state_hash"]]
    # The canonical devnet alloc materializes the synthetic terminal account state; no
    # historical transaction execution or snapshot download occurs. Install only into an
    # independently owned copy of MDBX, exactly like the real importer.
    source = directory / "source"
    el = directory / "el"
    el_bin = os.environ.get("ETNA_EL_BIN", ROOT / "target/etna-signer/alethia-reth")
    el_helper = os.environ.get("ETNA_EL_IMPORT_BIN", ROOT / "target/etna-signer/etna-el-import")
    measure("el-source", [el_bin, "init", "--datadir", source, "--chain",
                          directory / "el-genesis.json", "--db.growth-step", "128MB"], directory, env)
    source_digest = file_digest(source / "db/mdbx.dat")
    el.mkdir(mode=0o700)
    (el / "db").mkdir()
    for name in ("database.version", "mdbx.dat"):
        shutil.copyfile(source / "db" / name, el / "db" / name)
    for phase in ("verify", "install"):
        if phase == "install":
            marker = el / ".etna-el-import-staging.json"
            marker.write_text(json.dumps(dict(schema=1, installation_id=v["installation_id"],
                                              manifest_hash=v["manifest_hash"])))
            marker.chmod(0o600)
        receipt = json.loads(measure("el-" + phase, [el_helper, phase, "--datadir", el,
            "--chain", directory / "el-genesis.json", "--manifest", directory / "headers.json",
            "--chain-id", "167001", "--trusted-el-hash", v["el_hash"],
            "--trusted-state-root", v["state_root"], "--trusted-genesis-hash", v["genesis_hash"],
            "--scratch-parent", directory / "spool"], directory, env))
        assert receipt["header_count"] == 65_533 and receipt["first_header"] == v["terminal_q"]
        assert receipt["finalized_hash"] == v["finalized_hash"] and receipt["block_hash"] == v["el_hash"]
        assert receipt["installed"] == (phase == "install")
    assert file_digest(source / "db/mdbx.dat") == source_digest
    print("el_installed", json.dumps(dict(whole_el_bytes=disk(el),
          static_file_bytes=disk(el / "static_files"),
          manifest_bytes=(directory / "headers.json").stat().st_size)), flush=True)
    results = []
    installed = directory / "comet"
    for phase in ("verify", "install"):
        command = [helper, phase, "--package", directory / "stock.json",
                   "--spool-parent", directory / "spool", *trust]
        if phase == "install":
            command.extend(["--home", installed])
        results.append(json.loads(measure("stock-" + phase, command, directory, env)))
    r = results[0]
    assert results[0] == results[1]
    assert (r["first_height"], r["last_height"], r["initial_height"], r["chain_id"]) == (
        v["first_height"], height, 1, v["chain_id"])
    assert r["block_id"]["hash"].removeprefix("0x").lower() == v["comet_hash"][2:]
    assert r["validators_hash"] == r["next_validators_hash"] == v["set_hash"]
    assert r["block_id"]["parts"]["total"] == v["part_total"]
    assert r["block_id"]["parts"]["hash"][2:].lower() == v["part_hash"].lower()
    # Reopen the actual installed database through stock export. Read the terminal fixture
    # frame from a stream (no full export or in-memory block array).
    pkg = json.loads((directory / "package.json").read_text())
    preimage = directory / "preimage"
    preimage.write_bytes(bytes.fromhex(pkg["validator_state"][2:]))
    reopened = directory / "reopened.json"
    measure("reopen", [helper, "export", "--home", installed, "--first-height", str(height),
                       "--last-height", str(height), "--validator-state", preimage,
                       "--output", reopened], directory, env)
    with (directory / "blocks.jsonl").open("rb") as frames:
        for line in frames:
            last = line
    output = json.loads(reopened.read_text())
    assert output["blocks"] == [json.loads(last)] and output["genesis"] == pkg["genesis"]
    assert output["validator_state"] == pkg["validator_state"]
    print("profile", json.dumps(dict(s=height, period=period, frames=v["frames"],
          el_prefix_headers=v["el_prefix_headers"], terminal_q=v["terminal_q"],
          l1_calls=v["l1_calls"], blocks_bytes=(directory/"blocks.jsonl").stat().st_size,
          stock_bytes=(directory/"stock.json").stat().st_size, installed_bytes=disk(installed),
          total_bytes=disk(directory))), flush=True)
    return v["l1_calls"]


def file_digest(path):
    with Path(path).open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def main():
    if not __debug__:
        raise RuntimeError("this acceptance gate requires Python assertions")
    exe = binary()
    helper = ROOT / "target/etna-signer/etna-comet-import"
    if not helper.exists():
        raise SystemExit("build the pinned helper with script/build_etna_signer.sh")
    print("verifier_sha256", file_digest(exe),
          "stock_sha256", file_digest(helper), flush=True)
    for period in (4, 1):
        calls = []
        for height in (200_004, 400_008):
            with tempfile.TemporaryDirectory(prefix="etna-signed-window-") as temp:
                calls.append(profile(Path(temp), exe, helper, height, period))
        assert calls[0] == calls[1], "a longer prefix added own-L1 requests"


if __name__ == "__main__":
    main()
