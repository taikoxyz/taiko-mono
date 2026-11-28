# Incomplete M05 experiment: two-slot-raw

Status: **INCONCLUSIVE**. The existing harness killed this case at its 45-second
limit (512 MiB heap, one worker, seed 1, TLC release 1.7.4). No final state counts
or queue-zero completion were observed. The last periodic progress report was
99,683 states generated, 36,508 distinct and 25,695 queued. These are
intermediate counts, not final search totals.

The exact module/config inputs are archived here; later fixes and more compact
observation records are intentionally not substituted into this historical run.

- `EtnaRegistry.tla`: `dd3ae90d4a9a50e8d0602442028d534db518ac178a7d5f3e6253151265a0aee4`
- `registry-two-slot.cfg`: `6b78495119b82bf4e9089c5afb1cf509b09f2dc3ec83450f58a23c0cc75db33d`

To reproduce with the shared harness, copy this module and configuration into
a temporary directory containing a copy of `formal/etna/check.py`, place the
configuration in its `configs/` subdirectory, and pass the caller-provided Java
executable, TLC jar and output directory. The archive is outside the default
configuration suite and is never counted as a passing default case.
