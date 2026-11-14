# Historical incomplete M06 experiment: prefix

These are exact historical inputs, not passing default cases. No final queue-zero
completion or exact final counts were observed. Periodic counts below are only
intermediate observations at the printed time. Tools: TLC release 1.7.4, Java 17,
512 MiB heap, one worker, seed 1; 45-second timeout per case.

- `fi-empty-revert`: **INCONCLUSIVE**, killed at 45 seconds. Last periodic observation: `Progress(10) at 2026-11-14 19:31:43: 74,361 states generated (74,361 s/min), 27,787 distinct states found (27,787 ds/min), 20,771 states left on queue.`. Configuration SHA-256 `3b8a02d45ff796c02612926eb40670acd0d80a311ac13aeb2d644c3e96638c77`.
- `fi-fee-lag`: **INCONCLUSIVE**, killed at 45 seconds. Last periodic observation: `Progress(11) at 2026-11-14 19:32:28: 74,261 states generated (74,261 s/min), 30,181 distinct states found (30,181 ds/min), 21,149 states left on queue.`. Configuration SHA-256 `b3c060336be5abf68bd6305cdee98a5d0dd0a252c6c231dc5f288d4abfe770fc`.
- `fi-mixed`: **INCONCLUSIVE**, killed at 45 seconds. Last periodic observation: `Progress(10) at 2026-11-14 19:33:13: 74,972 states generated (74,972 s/min), 32,384 distinct states found (32,384 ds/min), 25,478 states left on queue.`. Configuration SHA-256 `f901fd43ce9b7ed3b551a51acecb41eb0b162a4b0cfc11c04fb557096b58cd00`.

FI module SHA-256: `b67dff82898d529f50766f1753d19ec9d6f2b03aabe9f9f74b63d43173a72464`.
Required unchanged base module SHA-256: `3fd57284128ea5a19966c2684161f909155a4730310972fee87d50eed009b84a`.

For portable reproduction, stage this FI module, the exact shared dependency
`../fi-base/EtnaSettlement.tla`, this `configs/` directory and a copy of
`formal/etna/check.py` together in a temporary directory. Invoke that staged
harness with caller-provided Java/TLC paths and output directory. The base must
be beside the FI module so TLA+ EXTENDS resolves it. Downloads are unnecessary.

Later source/observer fixes are intentionally not substituted into these archived
inputs. Their larger products remain incomplete; the final source-valid prefixes
are not claimed equivalent to them.
