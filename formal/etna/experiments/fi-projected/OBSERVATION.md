# Historical incomplete M06 experiment: projected

These are exact historical inputs, not passing default cases. No final queue-zero
completion or exact final counts were observed. Periodic counts below are only
intermediate observations at the printed time. Tools: TLC release 1.7.4, Java 17,
512 MiB heap, one worker, seed 1; 45-second timeout per case.

- `fi-empty-revert`: **INCONCLUSIVE**, killed at 45 seconds. Last periodic observation: `Progress(11) at 2026-11-14 19:40:21: 71,303 states generated (71,303 s/min), 27,185 distinct states found (27,185 ds/min), 18,297 states left on queue.`. Configuration SHA-256 `b127f999495694925f01732c0c010d26695a43f39c6944ac2b0c5a3014cc99d3`.
- `fi-mixed`: **INCONCLUSIVE**, killed at 45 seconds. Last periodic observation: `Progress(10) at 2026-11-14 19:41:14: 67,448 states generated (67,448 s/min), 28,967 distinct states found (28,967 ds/min), 21,766 states left on queue.`. Configuration SHA-256 `49efe348f24abfeb34bbb8c5c036ec2f48579036bc673b00a607dd511236dc5f`.

FI module SHA-256: `4b0630076730e46ca5af773ab7254f51ace45c5e2c1887b5d333adfeec50d344`.
Required unchanged base module SHA-256: `3fd57284128ea5a19966c2684161f909155a4730310972fee87d50eed009b84a`.

For portable reproduction, stage this FI module, the exact shared dependency
`../fi-base/EtnaSettlement.tla`, this `configs/` directory and a copy of
`formal/etna/check.py` together in a temporary directory. Invoke that staged
harness with caller-provided Java/TLC paths and output directory. The base must
be beside the FI module so TLA+ EXTENDS resolves it. Downloads are unnecessary.

Later source/observer fixes are intentionally not substituted into these archived
inputs. Their larger products remain incomplete; the final source-valid prefixes
are not claimed equivalent to them.
