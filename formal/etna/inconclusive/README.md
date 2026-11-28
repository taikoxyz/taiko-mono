# Inconclusive latest-source searches

The L2 committee/recovery Free safety obligation remains **OPEN**. Three
45-second searches preceded the stale-recovery budget guard correction. A fourth
actual45-second search on the corrected6de kernel also did not exhaust the
absolute height14 graph. The original config still expects PASS; timeout fails
the unchanged runner. These are revision-qualified attempts on one obligation,
separate from19 historical inconclusive cases.

The default bank is503 = the byte-identical493 historical configs plus ten
scheduled witnesses. Green default CI provides no new Free safety evidence.
Witnesses establish conditional existence, not unrestricted exhaustion or
temporal liveness. See the [stage report](../L2_COMMITTEE_RECOVERY.md) and
[projection proof](../L2_COMMITTEE_SAFETY_PROJECTION.md).

Reproduce from the repository root with an existing official TLC jar and JRE:

```sh
python formal/etna/check.py --java java --tlc-jar "$TLC_JAR" \
  --config-dir formal/etna/inconclusive/configs --case l2cr-safety \
  --output-dir "$OUTPUT_DIR" --timeout 45 --heap-mb 512
```

[`results.json`](results.json) records the exact module/config/result/receipt
and original raw-log digests. The four original timeout logs are retained in
`evidence/`. Periodic samples in those logs are not final graph counts. The
current model and separate config reproduce the corrected-kernel attempt; historical
attempts retain their own identities and are not relabeled as current results.
