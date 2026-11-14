# Incomplete M05 experiment: fixed-init

Status: **INCONCLUSIVE**. The existing harness killed this case at its 45-second
limit (512 MiB heap, one worker, seed 1, TLC release 1.7.4). No final state counts
or queue-zero completion were observed. The last periodic progress report was
101,592 states generated, 38,636 distinct and 21,847 queued. These are
intermediate counts, not final search totals.

The exact module/config inputs are archived here; later fixes and more compact
observation records are intentionally not substituted into this historical run.

- `EtnaRegistry.tla`: `236099023b8bf8565adb96f02352f9aac9ae4ada5d1fda8432809882fe374441`
- `registry-workflow.cfg`: `fb59d91cca159c37c0bf51e298e4731c5f01eba500a508615f3284c003c83a27`

To reproduce with the shared harness, copy this module and configuration into
a temporary directory containing a copy of `formal/etna/check.py`, place the
configuration in its `configs/` subdirectory, and pass the caller-provided Java
executable, TLC jar and output directory. The archive is outside the default
configuration suite and is never counted as a passing default case.
