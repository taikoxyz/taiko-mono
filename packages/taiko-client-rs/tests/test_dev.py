"""Select a short local verification run from the worktree's changes."""

import argparse
import os
from pathlib import Path
import re
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LANDER_RESTART = ("lander_cli", "lander_cli_recovers_from_sigkill_and_resumes_after_sigterm")
ABCI_START = ("single_validator", "single_validator_produces_blocks_by_the_header_rules")
RECOVER = ("governance_recovery", "governance_recovery_command_produces_and_lands")
IMPORT = ("governance_recovery", "checkpoint_import_fixed_origin_runs_original_stock_init_chain")
MIXED_TEST_TARGETS = {"cleanup", "lander_cli"}


def git(*args, cwd=ROOT):
    return subprocess.check_output(["git", *args], cwd=cwd)


def changed_paths(base):
    repo = Path(os.fsdecode(git("rev-parse", "--show-toplevel").rstrip(b"\n")))
    revision = git("rev-parse", "--verify", "--end-of-options", f"{base}^{{commit}}").decode().strip()
    fork = git("merge-base", "HEAD", revision).decode().strip()
    scope = (ROOT.relative_to(repo).as_posix(), "packages/protocol",
             ".github/actions/setup-taiko-client-rs", ".github/workflows/taiko-client-rs--test.yml")
    tracked = git("diff", "--name-only", "--no-renames", "-z", fork, "--", *scope, cwd=repo)
    untracked = git("ls-files", "--others", "--exclude-standard", "-z", "--", *scope, cwd=repo)
    return sorted({repo / os.fsdecode(path) for path in (tracked + untracked).split(b"\0") if path})


def native(package, *targets):
    return ("cargo", "test", "-p", package, "--all-features", *targets)


def commands_for(path):
    """Return native and Docker commands for a focused change, or None for shared inputs."""
    target = re.fullmatch(r"(?:crates/([^/]+)|bin/client)/tests/([^/]+)\.rs", path)
    if target and (ROOT / path).is_file():
        crate, binary = target.groups()
        source = (ROOT / path).read_text()
        if re.search(r'#\[ignore\s*=\s*"[^"]*docker', source, re.IGNORECASE):
            # These binaries also have native tests, so exercise both tiers.
            local = native(crate or "taiko-client", "--test", binary) if binary in MIXED_TEST_TARGETS else None
            return local, ("just", "test-full", "--test", binary)
        return native(crate or "taiko-client", "--test", binary), None

    if path.startswith("crates/abci/src/"):
        return native("abci", "--lib"), ("just", "test", "--test", *ABCI_START)
    if path.startswith("crates/lander/src/"):
        return native("lander", "--lib"), ("just", "test", "--test", *LANDER_RESTART)
    if path in {"bin/client/src/commands/lander.rs", "bin/client/src/flags/lander.rs"}:
        return native("taiko-client", "--test", "lander_cli"), ("just", "test", "--test", *LANDER_RESTART)
    if path == "bin/client/src/commands/abci_recover.rs" or path.startswith("bin/client/src/recovery/"):
        return native("taiko-client", "--bin", "taiko-client"), ("just", "test", "--test", *RECOVER)
    if path == "bin/client/src/commands/abci_import.rs" or path.startswith("bin/client/src/import/"):
        return native("taiko-client", "--bin", "taiko-client"), ("just", "test", "--test", *IMPORT)
    if path.startswith(("bin/client/tests/support/checkpoint_import", "bin/client/tests/support/recovery")):
        return None, ("just", "test-full", "--test", "governance_recovery")
    if path.startswith(("crates/etna-core/src/", "crates/driver/src/")):
        return native(path.split("/")[1], "--lib"), None
    if path.startswith("tools/etna-signer/"):
        return ("just", "signer-test"), ("just", "test", "--test", *ABCI_START)
    if path.startswith("tools/etna-el-import/"):
        return ("just", "el-import-verify"), None
    if path.startswith(("script/", "tests/")):
        return ("just", "supervisor-test"), ("just", "test-smoke")
    return None


def plan(paths):
    local, docker = set(), set()
    shared = False
    for path in paths:
        if path.suffix.lower() == ".md":
            continue
        relative = path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else str(path)
        commands = commands_for(relative)
        if commands is None:
            print(f"{relative} → shared or unmapped input", flush=True)
            shared = True
            continue
        unit, scenario = commands
        print(f"{relative} → {' + '.join(shlex.join(cmd) for cmd in commands if cmd)}", flush=True)
        if unit:
            local.add(unit)
        if scenario:
            docker.add(scenario)
    if shared:
        local = {cmd for cmd in local if cmd[0] == "just"} | {("just", "unit")}
        docker.add(("just", "test-smoke"))
    if ("just", "test-smoke") in docker:
        docker.discard(("just", "test", "--test", *ABCI_START))
        docker.discard(("just", "test", "--test", *LANDER_RESTART))
    if not local and not docker:
        print("No code or test changes selected. Running the smoke scenarios.", flush=True)
        docker.add(("just", "test-smoke"))
    return sorted(local) + sorted(docker)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", nargs="?", default="HEAD", help="include commits since the merge base with this ref")
    parser.add_argument("--dry-run", action="store_true", help="print the selected commands")
    args = parser.parse_args()
    try:
        commands = plan(changed_paths(args.base))
    except subprocess.CalledProcessError as error:
        parser.exit(error.returncode)

    env = os.environ.copy()
    env.setdefault("PULL_POLICY", "missing")
    for command in commands:
        print(f"+ {shlex.join(command)}", flush=True)
        if not args.dry_run:
            # Let the final command receive cancellation directly.
            if command == commands[-1]:
                os.chdir(ROOT)
                os.execvpe(command[0], command, env)
            status = subprocess.run(command, cwd=ROOT, env=env).returncode
            if status:
                return status if status > 0 else 128 - status
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
