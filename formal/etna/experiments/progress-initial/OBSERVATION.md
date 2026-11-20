# Historical M07 initial prototype: incomplete

Status: **INCONCLUSIVE**, not a passing default case. This exact prototype was
measured before repairing reference/finality clock conformance. It is historical
modeling/cost evidence, not an incomplete verification of the final model's exact
semantics. The corrected unrestricted dynamic-arrival product was not exhausted;
final ready/absent profiles are not claimed equivalent to this product.

Module SHA-256: `42376253c4cd531596952ae2b0a5a03b82295ba8b0c9aa6e1a42e828dc4d4e2d`.

- `progress-ancestry`: killed at 45 seconds; last periodic observation `Progress(11) at 2026-11-14 20:04:10: 102,675 states generated (102,675 s/min), 21,770 distinct states found (21,770 ds/min), 14,504 states left on queue.`; config SHA-256 `c65ca8675bfc3172639ea3a26f2ba3c3c058187c72659f3b04dfd3d02b297f98`.
- `progress-pipeline`: killed at 45 seconds; last periodic observation `Progress(13) at 2026-11-14 20:04:55: 99,505 states generated (99,505 s/min), 18,947 distinct states found (18,947 ds/min), 12,640 states left on queue.`; config SHA-256 `906b52f3d17640c8a9fb692288d8aac926ef9b06223dd54433ea68402c750678`.
- `progress-small-capacity`: killed at 45 seconds; last periodic observation `Progress(13) at 2026-11-14 20:05:40: 100,381 states generated (100,381 s/min), 19,122 distinct states found (19,122 ds/min), 12,766 states left on queue.`; config SHA-256 `bfbd5a781202eab9e437a95211b64bf2f999361d6ae9c105c9b5e601c403d3b3`.

Counts are intermediate periodic observations, not exact final search totals.
No queue-zero completion was observed. Parameters: TLC release 1.7.4, Java 17,
512 MiB heap, one worker, seed 1, 45-second timeout per case.

For portable reproduction, stage this standalone module, its `configs/` and a
copy of `formal/etna/check.py` together in a temporary directory. Invoke the
staged harness with caller-supplied Java/TLC paths and output directory. There
is no project-module dependency and no download is required. This directory is
outside the default configuration suite. Later repairs are not substituted into
the historical inputs.
