# Archived incomplete wide runtime

Status: INCONCLUSIVE, 45s timeout, 512MiB, one TLC worker. Last emitted progress
(depth18): 152,614 generated; 34,626 distinct; 19,607 queued. No final count or
exhaustion was observed. This archive is outside the default configuration suite.

Exact SHA-256:

- EtnaVerifierRollback.tla: a6372f24c9255a1b4affdad33792f273ac3267d5dd5a12fcc4cc31f9047d84a3
- EtnaSettlement.tla: 3fd57284128ea5a19966c2684161f909155a4730310972fee87d50eed009b84a

Run from this directory so the archived dependency resolves. Supply existing Java
and TLC paths; choose a local timeout tool if desired. The original command had a
45-second runner deadline; a direct TLC run below has no completion claim.

```sh
"$JAVA" -Xmx512m -XX:+UseParallelGC -cp "$TLC_JAR" tlc2.TLC -workers 1 -seed 1 \
  -deadlock -metadir "$TLC_OUTPUT_DIR/states" \
  -config configs/rollback-replay.cfg EtnaVerifierRollback.tla
```

The current checked model uses explicitly prepared operator workloads, so its
successful completion is not evidence that this larger graph completes or holds.

Set TLC_OUTPUT_DIR to a caller-owned path outside Git. This preserved prototype
predates the base landing-record assertion repair described in the current
module document; its assertions must not be silently treated as the final set,
even if a later rerun finishes. No historical source is retroactively patched.
