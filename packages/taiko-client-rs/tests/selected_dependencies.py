"""Map nextest's matched cases to the native runtimes they actually use."""
import json
import sys

RECOVERY_IMAGE = {
    "governance_recovery_linux_comet_uid_reads_p2p_and_cannot_read_registered_key",
    "governance_recovery_sigkill_boundaries_replay_without_duplicate_owners",
}
LONG_FENCE = "support::checkpoint_import::long_fence::native_long_fence_restarts_and_executes_with_body_pruned_parents"
NATIVE_EL = {
    "support::checkpoint_import::checkpoint_import_older_archive_restarts_and_syncs_stock_peer",
    "support::checkpoint_import::checkpoint_import_latest_restarts_and_syncs_stock_peer",
    "support::checkpoint_import::checkpoint_import_fixed_origin_runs_original_stock_init_chain",
    "support::checkpoint_import::registered_checkpoint_latest_signs_proposes_and_lands",
    "support::checkpoint_import::registered_checkpoint_older_signs_proposes_and_lands",
    "support::checkpoint_import::checkpoint_import_first_and_cold_post_floor_forced_skips",
    "checkpoint_import_recovered_fixed_and_landed_points_continue_stock",
    LONG_FENCE,
}


def dependencies(data):
    """Ignore excluded suites/cases; preserve module-qualified test identity."""
    needed = set()
    for suite in data["rust-suites"].values():
        if suite["status"] != "listed":
            continue
        for name, case in suite["testcases"].items():
            if case["filter-match"]["status"] != "matches":
                continue
            needed.add("docker")
            recovery = (suite["package-name"], suite["binary-name"]) == ("taiko-client", "governance_recovery")
            if recovery and name == LONG_FENCE:
                needed.add("el")
                continue
            docker_only = (suite["package-name"], suite["binary-name"]) in {
                ("test-harness", "cleanup"),
                ("test-harness", "standalone_reth"),
            }
            if not docker_only:
                needed.add("signer")
            if recovery:
                needed.add("comet")
                if name in NATIVE_EL:
                    needed.add("el")
                if name in RECOVERY_IMAGE:
                    needed.add("recovery")
    return " ".join(sorted(needed))


if __name__ == "__main__":
    print(dependencies(json.load(sys.stdin)))
