# Questions for the Design Authors

Open questions from the DeepSeek independent adversarial review of PR #22034 (v14 design), 2026-08-21.
Grouped by report; each question cites the finding it comes from.

## Timestamp & anchor (report 04)

1. **What defines T_N?** Every bound is epoch-relative, but the origin of the epoch clock is never stated
   (T_N = T_0 + N·E with T_0 = deployment time? L1-genesis-relative? Re-based on lag?). What is the exact
   slot-mapping/rounding rule for slot(T_N) when T_0 is not slot-aligned? (04 §4.8, HIGH)

2. **What is the consensus rule for future-stamped blocks?** The [T_N, T_N+E) window permits +383 s stamps
   that execution clients will reject (geth-class future-block tolerance; taiko-geth not in this repo). Is the
   intended rule "ts ≤ local clock + tolerance" (soft, non-objective) or an objective replacement bound — and
   where is it pinned as circuit-canonical + client-identical? (04 §4.2, HIGH)

3. **Why is there no upper bound on freshness_ceiling?** The setter enforces ceiling ≥ D_anchor + Γc + κ + R + margin
   (~55 slots), but nothing caps it above. The holder's per-signal L1→L2 ingestion-delay lever is exactly
   (ceiling − D_anchor), ratcheted across epochs. Will you add a ceiling ≤ 2·D_anchor + Γc + κ + R + margin-style
   upper setter bound? (04 §4.6, MEDIUM)

## L1-evaluability (report 01)

4. **How does the DEFAULT-mode seal authenticate F(N)?** The L1 contract cannot map past slots to block numbers.
   Is the intended mechanism an EIP-4788 proof of latest_execution_payload_header recorded in the spine at decision
   time (before the 8191-slot root buffer expires for late/cancellation-path seals), or something else? Without it,
   the forced-only seal is either unconstructible or caller-claimable — §13-S.18 names the mode pinning but not this
   binding. (01 §S2, HIGH)

5. **How is the anarchy proposal's anchor eligibility checked at late landing?** "Depth/freshness measured against
   N's own schedule, never landing-relative" needs historical L1 state at D_N that the L1 contract cannot read at
   landing (up to W_a·E later). Same machinery as Q4, or a spine record of blockAt(slot(D_N))? (01 §S3, HIGH)

6. **How is the fill-reward trigger computed?** Commitment inclusion cannot distinguish the holder's own slice from
   a filler's identical re-post. Will the EBC bind the holder's own blob-transaction hashes (making "holder failed
   to post" computable), or is the fill reward dropped? (01 §S4, MEDIUM)

## Auction economics (reports 03 & 05)

7. **Where is the v1–v6 baseline?** §4 (auction mechanics: bid composition, increments, reserve, q-delay,
   current+next final, standby promotion, funding rule), §6.1–6.6, §7, §10.2 are "as v3" — and no file in the PR
   contains that text. Will the normative record inline or archive it? (06 §R2)

8. **What is the funding-forfeit rule?** If the winning bidder fails to fund and merely "quits", a griefer displaces
   a serving incumbent with a phantom bid at zero cost, repeatedly. Is there a forfeitable bid bond, binding
   funding at bid, or a slash on failure to fund? (03 §3.4, HIGH)

9. **Will the proposal restate the seat-fee destination?** status-quo.md §6.1 records the owner decision ("per-epoch
   fee in ETH, paid to the treasury/DAO"), but the proposal's §4/§10.2 never restate it — the normative record depends
   on a companion file. Confirming/restating it (treasury/DAO) in §4 would also make explicit that the auction is
   protocol revenue, which makes the reserve-floor calibration in thin markets (Q8's sibling) revenue-critical. (05 §5.1)

10. **What is the bootstrap and transition-service rule?** At deployment (and after all tenures terminate), does the
    chain start in Total Anarchy until the first auction clears? During the q-epoch transition (outbid/termination),
    who sequences the still-assigned epochs and the gap? (03 §3.4)

## Deterrence economics (report 05)

11. **Is L_safety sized for p < 1?** The formula L_safety ≥ Λ·MEV deters only when a watchtower acts with probability

    1. Since the double-EBC variant self-materializes and preconf-vs-record does not, a rational equivocator chooses
       the latter and bets on p < 1. Will you size L_safety ≥ Λ·MEV/p_target for an explicit p_target, or adopt the
       bonded-accusation suspension (§13-T.12) as the primary deterrent? (05 §5.3)

12. **Who estimates per-epoch extractable MEV, and how?** With no oracles (I9), the central theft deterrent is a
    governance forecast re-made every T_max. Is there a forecast procedure, a spike-inclusive worst-case bound
    (§13-S.4), or an acceptance that the suspension option carries the load? (05 §5.4)

## Verification artifact (report 07)

13. **Will the checker model the v14 cancel-on-blob-expiry rule, T_max, K_empty, and the auction?** The round-12
    Codex fidelity fixes were applied; the v14 design commit's own newest rule (§6.7 blob-expiry cancellation) still
    has no transition in the checker, and W_a = 4 is structurally uncheckable (hard error at W_ANARCHY > 2). What
    bounds would make W_a = 4 and NEPOCHS = 3 tractable? (07 §7.3)

14. **Will RESULTS.md/README wording be corrected?** "relation already contains every v10/v11/v14 mechanism" and
    "no permanent halt exists" both overstate the verified claim (deadlock-freedom, logical epoch machine only). (07 §7.5)

## Misc

15. **§5.2's fill reward trigger** — same as Q6 (the trigger, not the payee, is the uncomputable part; 01 §S4).

16. **Do you accept the censor-race economics as quantified?** (net ≈ +0.02 ETH/epoch under partial forced-fee
    coverage, ≈ −0.01 net-subsidized when fees over-cover) — and if so, is the intended countermeasure solely the
    exit-by-bidding (G5) path plus §13-T.14 quantification? (03 §3.3)
