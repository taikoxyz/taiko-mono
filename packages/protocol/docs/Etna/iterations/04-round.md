# Round 04 — codec closed; bootstrap and capture economics incomplete

Reviewed snapshot: `96fcdecec06a4993834549085758b55e90191703`. Fresh independent reviewers: **gpt-6.1-sol** [A](04-a.md), **gpt-6-astra** [B](04-b.md), **gpt-6-sol** [C](04-c.md), all requested at high reasoning. The separate fresh [judge](04-judge.md) had no design authorship; its inherited model name was unexposed. Coordination and independent-read order are disclosed in the judge report.

**Zero new confirmed Critical/High. Not converged: R6 and R7 do not fully pass.** The exact inner codec and component fixtures close J03-01 at specification level. All twelve fixture hashes were independently reproduced; no production execution proof or benchmark was run.

- **J04-01, new Medium, required fix:** activation omits exact initial origin, queue snapshot and segment commitment assignments. Specify the entire bootstrap head and first successor, preserving pending requests and fees. Check the combined first calldata body; independently bounded components alone do not prove it fits.
- **J04-02, reopened Medium, required fix:** optional service reserves and force-spam fees do not attach to repeated ordinary canonical capture. Add a mandatory permissionless economic mechanism with a bounded cost/gain argument, or leave R6 explicitly unmet. Prior acceptance of concentration risk cannot waive this gate.
- **C-F1, proposed High, rejected:** a timely paid response meets the currently specified service obligation. Nevertheless, the revision will strengthen bonded early blocks with an absolute public-fragment deadline, because that makes more withholding objectively punishable. This is a deliberate improvement, not a claim that the old service secretly provided that duty.
- **Accepted Medium:** cross-owner and cross-segment attribution remains bounded. No identity oracle, irreversible soft branch or unlimited MEV compensation is claimed.

Next revision: exact zero-sentinel bootstrap; mandatory public fragment covenants for bonded claims; a per-head descending-price admission rent with no reserved winner and a zero-price fallback. These are proposed corrections awaiting specification and fresh round05 review, not current passing mechanisms. No impossibility theorem is established.
