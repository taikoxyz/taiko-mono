"""Map nextest's matched cases to the native runtimes they actually use. With --client-bin, print
the taiko-client executable that the listing's build produced instead."""
import json
import os
import sys

# The only (package, binary) whose cases need stock Comet, the native EL or the recovery image.
# The entrypoint's `native` lane selects exactly this binary; widen both together.
NATIVE_SUITE = ("taiko-client", "governance_recovery")
DEVNET_IMAGES = {"anvil-image", "reth-image", "comet-image"}
CONTRACT_IMAGES = {"lander-anvil-image", "reth-image"}
SUITE_IMAGES = {
    ("test-harness", "cleanup"): {"lander-anvil-image"},
    ("test-harness", "standalone_reth"): {"reth-image"},
    ("taiko-client", "lander_cli"): CONTRACT_IMAGES,
    NATIVE_SUITE: CONTRACT_IMAGES,
    ("lander", "landing"): CONTRACT_IMAGES,
    ("lander", "recovery"): CONTRACT_IMAGES,
    ("lander", "native_acceptance"): CONTRACT_IMAGES | {"comet-image"},
    ("lander", "staking"): CONTRACT_IMAGES | {"comet-image"},
    ("lander", "switch"): CONTRACT_IMAGES,
    ("lander", "collector"): DEVNET_IMAGES,
}
ALL_IMAGES = DEVNET_IMAGES | CONTRACT_IMAGES
ALL_DEPENDENCIES = ALL_IMAGES | {"docker", "signer", "comet", "el", "recovery"}
RECOVERY_IMAGE = {
    "governance_recovery_linux_comet_uid_reads_p2p_and_cannot_read_registered_key",
}
LONG_FENCE = "support::checkpoint_import::long_fence::native_long_fence_restarts_and_executes_with_body_pruned_parents"
NATIVE_EL = {
    "support::checkpoint_import::checkpoint_import_latest_full_node_restarts_forced_skips_and_retries",
    "support::checkpoint_import::registered_checkpoint_older_signs_proposes_and_lands",
    "support::checkpoint_import::checkpoint_import_fixed_origin_runs_original_stock_init_chain",
    "checkpoint_import_recovered_fixed_and_landed_points_continue_stock",
    LONG_FENCE,
}


def dependencies(data):
    """Ignore excluded suites/cases; preserve module-qualified test identity."""
    needed = set()
    for suite in data["rust-suites"].values():
        if suite["status"] != "listed":
            continue
        binary = (suite["package-name"], suite["binary-name"])
        for name, case in suite["testcases"].items():
            if case["filter-match"]["status"] != "matches":
                continue
            needed.add("docker")
            if binary == NATIVE_SUITE and name == LONG_FENCE:
                # This case only starts the native EL. Its helper can reuse a cached image on Linux.
                needed.add("el")
                continue
            # Unknown test binaries get every image. ABCI scenarios share the standard devnet.
            needed.update(SUITE_IMAGES.get(binary, DEVNET_IMAGES if binary[0] == "abci" else ALL_IMAGES))
            if binary not in {
                ("test-harness", "cleanup"),
                ("test-harness", "standalone_reth"),
            }:
                needed.add("signer")
            if binary == NATIVE_SUITE:
                needed.add("comet")
                if name in NATIVE_EL:
                    needed.add("el")
                if name in RECOVERY_IMAGE:
                    needed.add("recovery")
    return " ".join(sorted(needed))


def client_binary(data):
    """The one taiko-client `bin-exe` among the listing's non-test binaries, whose path is relative to
    the target directory. The recovery runtime image runs this host-built executable."""
    meta = data["rust-build-meta"]
    paths = [binary["path"] for binaries in meta["non-test-binaries"].values() for binary in binaries
             if binary["name"] == "taiko-client" and binary["kind"] == "bin-exe"]
    if len(paths) != 1:
        raise SystemExit(f"expected one taiko-client bin-exe in the nextest listing, found {len(paths)}")
    return os.path.join(meta["target-directory"], paths[0])


if __name__ == "__main__":
    match sys.argv[1:]:
        case ["--all"]:
            print(" ".join(sorted(ALL_DEPENDENCIES)))
        case ["--client-bin"]:
            print(client_binary(json.load(sys.stdin)))
        case []:
            print(dependencies(json.load(sys.stdin)))
        case _:
            raise SystemExit("usage: selected_dependencies.py [--all | --client-bin] < nextest-list.json")
