# Incomplete M05 experiment: rich-receipt

Status: **INCONCLUSIVE**. The existing harness killed this case at its 45-second
limit (512 MiB heap, one worker, seed 1, TLC release 1.7.4). No final state counts
or queue-zero completion were observed. The last periodic progress report was
78,690 states generated, 20,383 distinct and 14,905 queued. These are
intermediate counts, not final search totals.

The exact module/config inputs are archived here; later fixes and more compact
observation records are intentionally not substituted into this historical run.

- `EtnaRegistry.tla`: `d254748f88a33ab12fb4df6fe90553d0c3e8a5a10ff7893bca08c49302609b74`
- `registry-two-slot.cfg`: `5b450d9d777b172ffafa740aed56a1a530069eba9f102b1f42c85e629d6ec97e`

To reproduce with the shared harness, copy this module and configuration into
a temporary directory containing a copy of `formal/etna/check.py`, place the
configuration in its `configs/` subdirectory, and pass the caller-provided Java
executable, TLC jar and output directory. The archive is outside the default
configuration suite and is never counted as a passing default case.
