# Incomplete M05 experiment: raw-init

Status: **INCONCLUSIVE**. The existing harness killed this case at its 45-second
limit (512 MiB heap, one worker, seed 1, TLC release 1.7.4). No final state counts
or queue-zero completion were observed. The last periodic progress report was
125,415 states generated, 42,259 distinct and 29,245 queued. These are
intermediate counts, not final search totals.

The exact module/config inputs are archived here; later fixes and more compact
observation records are intentionally not substituted into this historical run.

- `EtnaRegistry.tla`: `e5c1106a85271a47fda08ec2172367af7a814638d37228cb65cbae7c602e7abe`
- `registry-workflow.cfg`: `586ee8274ae1da230fa8aefdcc680b3e805e2165afa628740d2e3c0d30b2c1a5`

To reproduce with the shared harness, copy this module and configuration into
a temporary directory containing a copy of `formal/etna/check.py`, place the
configuration in its `configs/` subdirectory, and pass the caller-provided Java
executable, TLC jar and output directory. The archive is outside the default
configuration suite and is never counted as a passing default case.
