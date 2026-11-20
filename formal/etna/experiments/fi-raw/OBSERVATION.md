# Historical incomplete M06 experiment: raw

These are exact historical inputs, not passing default cases. No final queue-zero
completion or exact final counts were observed. Periodic counts below are only
intermediate observations at the printed time. Tools: TLC release 1.7.4, Java 17,
512 MiB heap, one worker, seed 1; 45-second timeout per case.

- `fi-empty-revert`: **INCONCLUSIVE**, killed at 45 seconds. Last periodic observation: `Progress(8) at 2026-11-14 19:27:21: 91,221 states generated (91,221 s/min), 36,262 distinct states found (36,262 ds/min), 28,321 states left on queue.`. Configuration SHA-256 `e6b5234ac16ffccb1a6f15095447f8f43209b10008d18a851e57f98daa4a70ef`.
- `fi-mixed`: **INCONCLUSIVE**, killed at 45 seconds. Last periodic observation: `Progress(8) at 2026-11-14 19:28:06: 86,686 states generated (86,686 s/min), 33,913 distinct states found (33,913 ds/min), 26,990 states left on queue.`. Configuration SHA-256 `984605821f31418b2b4bb74a57ef82705a7338114ca22a278f6b3775ad1a98d6`.

FI module SHA-256: `e2dfa04e24692e8341e213d65a16469ec4c5d8bddcd93c44e81dedf5a8c754f1`.
Required unchanged base module SHA-256: `3fd57284128ea5a19966c2684161f909155a4730310972fee87d50eed009b84a`.

For portable reproduction, stage this FI module, the exact shared dependency
`../fi-base/EtnaSettlement.tla`, this `configs/` directory and a copy of
`formal/etna/check.py` together in a temporary directory. Invoke that staged
harness with caller-provided Java/TLC paths and output directory. The base must
be beside the FI module so TLA+ EXTENDS resolves it. Downloads are unnecessary.

Later source/observer fixes are intentionally not substituted into these archived
inputs. Their larger products remain incomplete; the final source-valid prefixes
are not claimed equivalent to them.
