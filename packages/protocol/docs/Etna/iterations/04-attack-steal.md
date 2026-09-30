# Round 4: steal attacker report

## Model
claude-opus-5-5 (self-reported; opus was requested).

## Method
I converted the design pages to text and read the index, roles, sequencing, preconf, landing, slashing (part) and interfaces pages. I also checked iterations/03-round.md for findings that are already known.

## Status
This session was interrupted before any finding was finished. This report contains no findings. The steal goal should be re-run in a new session.

## What I tried and could not finish
- Recorded-REPLACE close (landing A3, recordViewChange): I did not finish the analysis.
- Per-landing reward R_LAND against the reserve (landing section 5): I did not finish the analysis.
- S3b against monotone lock votes: honest votes are always at or above the attester's own lock (preconf section 5, "lock* >= its own lock"), so I found no false S3b on honest keys.
- S3d: the reference is inside the signed bytes and canonicality is checked, so I found no framing.
- S3c: re-voting upward is allowed, so I found no equivocation from honest re-votes.
- MISS penalty: it is burned and applied once per (t, v), so a false view change pays nobody.
- Reward debits: they are drawn from the reserve, never from seat stake (slashing section 1).
