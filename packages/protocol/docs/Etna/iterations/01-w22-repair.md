# W22: B's repair candidate after Cycle-2 round 1

**[assumed: provenance]** Reviewed base: D78 `cc4b077668b54d8faa02ebf58be37f7ff9045e3a`. [A's round-1 report and order](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5971793483) assigns five findings to B; [J's review brief](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5972008193) requires a protocol closure or a new user decision. B chooses a protocol proposal. This is a local repair review, not another clean convergence round or J's independent judgment. A owns the other eleven findings, WORK statuses and arbitration.

**[open: disposition]** Candidate only. A/J review, affected-owner adoption and exact fixtures remain outstanding. D73 accepts G5/G5-F, not the new same-opening interleaving defect. Two consecutive clean red-team rounds have not occurred. No implementation or performance result is claimed.

## Assigned findings and proposed disposition

| Finding | Base severity | Proposal and owning rules | Closure still required |
|---|---|---|---|
| safety-locked-interleaved-branch-closing | High | S2-R03 authenticates PH parent identity; R04/R06 persist branch history; R09 closes only along the certificate lock; R21 extends S3a/S3b to authenticated branches. V38/V39 and §7 give schedules and the conditional bound. | A/J attack; C1/C2/C7/C8 PH adoption; S3 evidence ABI/cost/fixtures. Until then the old D1 bound is disputed. |
| safety-stale-view-resume-unbuildable | Medium | S2-R15 preserves same-term RESUME, then empty authenticated closings reach a timely term. R22 permits bounded requested recovery control. V40/V42. | **Not closed:** long empty-prefix admission still lacks bounded C2 progression; co-owned C2/S2/C8 repair and the other owner adoptions remain required. |
| safety-fallback-votes-dropped-prerelay | Low | R07/R22 authenticate later committee membership, separate timeout-certificate buckets by the unsigned routing selector, and never slash transport metadata. V41. | C8 message and negative-byte fixtures. |
| migration-bridge-03 | Low | C4-R03 authenticates a historical installation checkpoint without equating it to the execution-time finalized tip; arming consumes that result. | C8 bounded context codec/storage/getter fixtures; A-MIGRATION-WITNESS. |
| migration-bridge-04 | Low | C4-R07 authenticates the exact terminal RLP header, decodes its L2 timestamp and seals the tuple atomically with READY. R04 does not invent a timestamp from legacy proving. T19. | C8 terminal context/width/error/namespace fixtures; witness availability. |

Each proposal above is **assumed** pending review. Its referenced proof is a conditional argument, not an executed conformance test.

## Reproducing the High

**[assumed: admissible schedule]** One logical opening X starts before height 39; one redraw has m=32 and Q=22. C40 is public. The adversary controls the leader and one committee position. Branches share height40. Twenty-one honest keys receive and execute A41 carrying C40, then B42 extending a conflicting B41 and carrying C40, then A43 extending A42 and carrying C_A41. The adversary privately completes each aggregate with its one signature. The honest keys attest only heights41,42,43 respectively; executing a parent does not imply attesting it. Selective timely delivery and withheld aggregate completion are premises, not indefinite censorship of honest gossip. For example issue A41 at E−4, B42 at E−2 stamped E−1, and A43 shortly afterward stamped E−2, within the existing receipt/skew rules; E is term end. Execution/gossip times are unmeasured.

**[proven: D78 counterexample]** Show C_A43 to a user: its carried C_A41 makes A41 locked. Then reveal C_B42. D78's height-only lock rule moves honest keys to B42; they close H_B42, displacing A41 inside X. No honest key has attested two headers at the same height. The carried heights 40,40,41 are no greater than vote42, so the old S3b does not apply. Only the leader's equal-height conflicting headers provide S1. The promised 12 attester positions do not follow. Role capital, private block/proof work and optional L1 submissions cost the attacker; MEV/user loss and gas are unmeasured. This violates the claimed D1/R6 backing, not the already accepted ancestor-opening G5 exception.

**[proven conditional: proposed refusal]** Under W22, a key that attested A41 refuses the incomparable B42. A key that instead attested B42 refuses A43. After ingesting C_A41, a key never replaces that certificate lock with incomparable C_B42 and never votes H_B42. If Byzantine keys nevertheless sign both incompatible certificates in one redraw, the new S3a branch witness exposes their intersection. If they attest A43 then vote H_B42, the new S3b witness compares C_A41 to the authenticated voted ancestry. §7 uses the locking certificate's signer set, not the carried target certificate's signer set, for the bound.

## Honest signing orders and evidence authentication

**[proven conditional]** R06's persistent tip makes all of one key's attestations in X a chain, across redraws. Its certificate lock advances only along authenticated ancestry. It ingests a carried certificate before signing. For attestation-before-H/F, the later vote must extend that certificate lock. For H/F-before-attestation, R04's persisted stop flag refuses the later attestation even if the voter never sent a timeout. An actual authorized reset permits only required RESUME messages under displaced generations; it does not erase old signatures or permit old H/F. A new opening has a different evidence scope. Thus the new forms do not frame an honest history under durable-record, hash/signature, C7-validity and permitted-reset assumptions.

**[assumed: evidence design]** R21's descent uses the higher endpoint's signed `parentPhHash` chain, not ancestor signatures or equality of execution hashes. Every supplied preimage/link is authenticated before its fields support guilt. Same-chain comparison returns NotConflicting; corrupt/unbound inputs refuse without debit. Equal-height forms remain compact. Out-of-X/synthetic locks do not acquire a fabricated PH body. Carried-C private-preimage availability remains S3's existing evidence limitation; the proposal claims no new oracle for missing data.

**[proven: derived size only]** Strict integer timestamps within S1's TERM=60 seconds bound same-opening endpoints to 59 parent links. Thirteen static ABI words per PH give 416 bytes per tuple and 24,544 bytes for 59 tuples. These are not complete transaction bytes or a gas ceiling. **[open: unmeasured]** Compression overhead, full evidence encoding, key proofs, BLS verification, payout cost, relay catch-up latency and migration header/installation-proof cost need the named C8/S3/C6 procedures. No gas-fit result or ready-to-launch parameter claim is made.

## Alternatives considered

- **[proven: insufficient alone]** A local no-switch policy without new objective evidence can prevent the one-malicious-position schedule under honest participation, but does not prove the promised slashable committee backing against Byzantine signers. It is not the selected repair.
- **[assumed: rejected larger change]** Requiring an immediate parent certificate for every block, reducing the opening exemption and authenticating every intermediate certificate on landing could support a different proof. Merely setting CERT_LAG_MAX=0 would not: the opening exemption and C2/C7's intermediate-witness checks also change. B rejects that pipeline/verification redesign as the minimal W22 fix; its latency/gas remain unmeasured.
- **[proven: unsafe evidence shortcut]** Comparing a caller-selected ancestor PH or an execution-hash alias without a signed PH-parent commitment can frame an honest key. Signed parent identity is therefore required by this proposal.
- **[assumed: not selected]** Disclosing another zero-evidence locked displacement would need a new user decision. B does not infer it from D73.

## Review and validation record

**[assumed: internal review record; configured models, not model self-identification]** Three independent adversaries reviewed the W22 candidate. They are not A or J and did not post to GitHub.

| Review | Configured model | Verdict and disposition |
|---|---|---|
| Funds / honest framing | gpt-6-astra | APPROVE the PH-ancestry/S3a/S3b and C4 mechanisms conditionally; no new attack found in that scope. REQUEST CHANGES on two later empty-cursor prototypes, both withdrawn. |
| Liveness / recovery | gpt-6-sol | REQUEST CHANGES: empty catch-up cannot be assumed to fit a block landing; a later cursor prototype and its guarded revision violate actual-landing recovery arbitration. These remain an explicit Medium recovery blocker; no cursor prototype survives in normative text. No separate F-relay or C4 defect found. |
| Accountability / monopoly | gpt-6.1-sol | APPROVE the conditional same-opening, same-draw branch proof; no new below-2Q−m displacement or framing schedule found in that scope. |

**[assumed: local disposition, not J's severity judgment]** The recovery review's initial Medium is retained open. The proposed fixes introduced High issues and were rejected, not accepted as risks:

1. **Long prefix:** with 100 illustrative empty closings and no timely old-term block, existing C2 cannot split the chain across block landings. The historical unmeasured ~165k/ordinary-VC estimate gives ~16.5M before RESUME, pins, calldata and the block proof, near the 16,777,216 cap. This is not an executed lower-bound estimate; it demonstrates why the existing disclosure cannot assert a fit. V43 now makes admission an explicit unresolved condition.
2. **Repeated recovery reference:** after actual recovery to L, consume RESUME(X→Y), lock Y descendants, then RESUME(Y→Z) at the same L/reference. Without recovery-source/one-use state, both scopes and signatures are valid and no listed slash applies. Quorum signatures plus call gas displace fresh locked transactions. A provenance/phase revision blocks this repetition.
3. **First RESUME over a surviving replacement generation:** even the guarded revision initializes from the replacement's post-landing Y. Certify new Y descendants before the first RESUME(Y→Z); its source/phase/reference are all valid. No later recovery landing justifies this fresh loss. The proposed gate alone is insufficient.
4. **Proof-free priority over REPLACE:** at head L, a recorded H closes X at L while an eligible REPLACE(X) fork is prepared. Advancing lastVCHash through H first invalidates that recovery's entry-opening proof without any landing choosing the branch. Restricting this to an actual-recovery session still permits the same race in successor Y after the first RESUME. An attacker pays one cursor call; certified replacement is denied, while certificate-free exits keep their separate conditions.

**[open: concrete next design obligation for A/B/C2/C8]** An incremental design must preserve an eligible REPLACE fork rooted before each empty advance, or explicitly revise the actual-landing arbitration with a new safety/liveness argument. A possible direction is a distinct authenticated recovery-fork cursor/history bound to the unchanged actual head, with bounded membership witnesses; it is not selected or claimed sound. Initial/repeated RESUME admission must separately distinguish certificate-free recovery from a replacement's already surviving ordinary generation. This is a technical integration blocker, not a request to silently accept another D1 residual. The current delivery contains the safe relay/local-progression repairs and records that the full stale-recovery task is unfinished.

**[proven: documentation checks, not protocol execution]** Local checks passed: 274 course file/fragment links, unique HTML ids, no scripts or network assets, exactly one definition of each S2-R01–R22 and C4-R01–R14, and an unchanged 1,904-byte D1 block matching D78 S2 and S3. The prior DECISIONS content is byte-preserved with a B proposal appended; WORK is unchanged; all repository edits are within Etna. C4 source checks confirm legacy CoreState/proof-time versus authenticated terminal-header semantics. Three B-owned C6 indexes pass 107 relative links and 17 local fragments; 17 immutable learning citations were checked. No production tests or measurements ran.

**[assumed: learning boundary]** The course adds D78 S2/S3 lessons, clearly marks round-1's disputed backing and links this candidate. The migration lesson distinguishes the pending W22 witness changes from accepted C4. Index pages publish merge/review state; they define no protocol rule. WORK and arbiter D rows are unchanged.


**[assumed: standing W8 review record]** B posted [REQUEST CHANGES on A's #22236 at `982aac6111a8c464542cee7d5d4c14d3369e0e9e`](https://github.com/taikoxyz/taiko-mono/pull/22236#issuecomment-5972414158): replay metadata authentication, false-FI-settlement trust scope, typed S3d expiry, collectible class-B cost and sparse sentinel term arithmetic. The comment gives exact quotes and narrower protocol alternatives before user escalation. A's PR is unmerged and these rules are not taught as accepted by the course.
