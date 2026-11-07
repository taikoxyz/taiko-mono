# Round 6 — raw adversarial review: the governance stall resolution and the signed generation

**Reviewer:** r6-gov-generations (task-5), fresh independent adversarial reviewer, round 6.
**Snapshot:** the specification content is at `7917ba264` (branch `etna-pos-zk`, PR #22262). HEAD is
`a483083ab` ("freeze snapshot 7917ba264 for review round 6"), whose only change is
`iterations/06-freeze.md` (`git diff --stat 7917ba264 HEAD` = 1 file, +18); working tree clean.
**Method:** rules judged as written. Italic in-text notes, "closes review round N" tags and the
decision log are claims, not evidence. Citation convention: `NN:line` = `spec/NN-*.html` line;
`D-n` = `DECISIONS.md`; `R5T-*` = round-5 raw reviews.

**Counts: Critical 1 · High 2 · Medium 3 · Low 1.**
**All three Critical/High findings are inside the claimed fault model: none needs a broken assumption,
a >1/3 Byzantine coalition, L1 censorship, or a malicious DAO.**

**Headline.** The resume-only *effect* is real: no calldata, no queue entry and no upgrade can name a
state, height, checkpoint, subset or validator set, and I could not construct a resolution that
executes after the checkpoint has advanced. The two defects are in the parts that were added today and
never reviewed. First, **nothing consumes a GOV-04 entry on execution** — the state enum is
`none/queued` and the only stated clearing rule is a cancellation that is unavailable once the trigger
holds — so the same entry stays executable forever and any account can re-execute it, incrementing
`recoveryGeneration` at will and voiding every in-flight certificate and proof: the one remedy D-15
keeps becomes a gas-priced, permissionless settlement-denial loop (or, on the strict reading of
"pending", permanently blocks every later entry). Second, **the timelock is not an exit window for the
class the resolution discards**: a release needs a withdrawal root at a newly settled epoch boundary,
and settlement advancing voids the entry, so "if the user can exit, the entry is void; if the entry
executes, the user could not exit" — no value of `T_GOV_RESUME` changes that, and the MUST that says
otherwise cannot be satisfied. Third, the generation binding is complete on the ordinary acceptance
path but **not on the anchor path**: the first epoch-opening batch after an executed resolution must
present `B_anchor`'s certificate, which is necessarily signed under the superseded generation, yet
PRF-05(ii)(a) judges it under PRF-04(i)'s equality with the journal's (new) generation.

---

## Finding G-1 — Critical: nothing consumes a GOV-04 entry on execution, so the sanctioned remedy for an unbounded halt is re-executable without any fresh trigger, and each re-execution voids every in-flight certificate and proof

**Severity: Critical.** One-line rationale: `govResumeState` is defined as `none/queued` with no
"executed" value and the only stated clearing rule is a cancellation that requires the entry to be
void, so after a successful execution the entry is still `queued`, still past its timelock, still not
void (execution "leaves the checkpoint record untouched"), and therefore still executable — by any
account, repeatedly, with no re-evaluation of the trigger — and each execution increments
`recoveryGeneration`, which voids every certificate and proof certified under the previous generation;
on the strict reading that "pending" is the stored state, the mirror failure obtains and the only named
exception of HALT-04 is permanently unavailable after one use.

**Exact rule / missing rule.**
- `08:766-773` (GOV-04(b)): "At most one entry may be pending at a time; a second queue attempt while
  one is pending MUST revert. Queueing records exactly three L1 facts: `govResumeQueuedAt` …,
  `govResumeQueuedHeight` (the `lastLandedHeight` at queue time) and `govResumeState = queued` (MIG-02
  slot 268)."
- `08:774-782` (GOV-04(c), *Effect*): on execution the action "sets `resumeHeight = lastLandedHeight + 1`
  … discards **everything above that checkpoint** …, **leaves the checkpoint record itself untouched**,
  and increments `recoveryGeneration` by exactly one." **The clause does not consume, clear or mark the
  entry.** It then says: "Execution is permissionless: once the timelock has elapsed and the entry is not
  void, any account may execute it."
- `08:783-789` (GOV-04(d)): "A queued entry becomes executable **no earlier than**
  `govResumeQueuedAt + T_GOV_RESUME`" — a one-sided predicate with no upper bound.
- `08:790-795` (GOV-04(e)): the only stated clearing of `govResumeState` is cancellation, which is
  permitted only for a **void** entry: "If the checkpoint advances at any time before execution —
  `lastLandedHeight > govResumeQueuedHeight` — the entry is void: execution MUST revert, and any account
  may cancel it, which clears `govResumeState`. … **No account may cancel an entry whose trigger still
  holds and whose checkpoint has not advanced.**"
- `08:279` (MIG-02 slot 268) and `09:177`: `govResumeState` is "`none/queued`" — the state model cannot
  represent "executed"; `01:220` states there is "**no recovery-completion record**". So an executed action
  is recorded by nothing except the counter increment.
- `06:412` (REC-02, *Repeated action*): "while the trigger still holds, **another entry may be queued and
  executed after its own timelock**. Each execution increments the generation again" — this row presumes a
  transition ("another entry may be queued") that no rule defines, and it is the only text that asserts
  the mechanism can be used more than once.
- **Missing rule:** *execution consumes the entry* — `govResumeState := none` on execution, a state value
  that distinguishes "executed" from "queued", and "a given entry executes at most once".

**Assumptions.** None beyond the rules. Step 3 below is the honest governance action D-15 requires; only
the *repeat* needs an ordinary L1 account. The attacker does not need to queue the entry, induce the
stall, hold stake or post a bond.

**Concrete attack trace.**
1. A settlement stall passes `T_STALL_GOV` (`06:401`). This is reachable with no adversary at all — the
   unfunded-landing-market residual (`06:436`, residual (4)).
2. Governance does exactly what D-15 requires: queues one entry against the current checkpoint `H`
   (`08:760-773`). The trigger is true; queueing is legal.
3. `T_GOV_RESUME` elapses with no accepted extending batch (any acceptance would have voided the entry,
   `08:790-795`). Any account executes: generation `g → g+1`, the range above `H` is discarded.
4. The entry is not consumed. `govResumeState` is still `queued`, `govResumeQueuedHeight` is still `H`,
   `lastLandedHeight` is still `H` (execution "leaves the checkpoint record untouched"). Every conjunct of
   "(timelock elapsed) ∧ (not void) ∧ (state queued)" still holds at the next L1 block, and again inside the
   same block: "any account may execute it". Each call increments `recoveryGeneration` by exactly one,
   which is what clause (c) requires of each call.
5. A batch can be accepted only under the generation the Inbox holds: the generation is L1-derived from
   storage into the journal (`04:163`, row 31; `05:198`), and the guest requires three-way agreement
   between the journal, every contributing vote and the head header (`05:274`; `02:180-181`). Producing a
   proof takes the D6 envelope (30 minutes = 900 blocks, `06:208-212`). A generation that changes at least
   once per L1 block (12 s) means no certified range can still be current when its proof lands. Settlement
   therefore cannot resume while the attacker keeps paying gas, the stall condition is never cleared, and
   no new checkpoint can ever exist.
6. Consequence: no new checkpoint means no new epoch-boundary checkpoint (`04:442`, L1-13(1)), so no new
   withdrawal root can form and every exit above the last root freezes; the provisional range is discarded
   by the rule and the remedy can never complete. The residual that D-15 selected the action to end — "an
   unbounded halt whose only remedies are outside the protocol" (D-7's rationale, kept by D-15) — is
   reachable by any account for gas.
7. *Mirror reading.* If "pending" in (b) is read as the stored state (the only stored representation,
   `none/queued`), then after one execution every later queue attempt MUST revert, the entry can never be
   cancelled ((e) is gated on voidness and the trigger still holds), and the `CONS-16` rotation is also
   blocked "while a stall-resolution entry of REC-02 is queued for execution" (`02:539-542`). The second
   settlement stall then has no remedy at all, and REC-02's own *Repeated action* row is false. The two
   readings are both conforming; the specification does not choose.

**Inside / outside the claimed fault model.** **Inside.** No assumption failure: not A-CONS-1/2, not A-L1-1,
not A-DA-2, no censorship, no Byzantine stake. The only precondition is the honest remedy being queued,
after which the attack is permissionless gas.

**Attacker resources and cost.** One L1 transaction per generation increment (a handful of storage writes),
permissionless, no bond and no stake — precisely the instrument D-15 withdrew (the bond, its escalation
and the completion predicate are tombstoned in `09:159-163`, `09:166-170`). The defender's only counter is
to prevent a stall from ever occurring; governance cannot retract the entry.

**Requirement / fixed decision affected.** **D-15** ("a timelocked, resume-only governance action clears a
stall"; and the withdrawal of the permissionless recovery, whose pricing mechanism is the only thing that
used to bound a permissionless actor on this path); **HALT-04** `06:219-246` ("There is exactly one named
exception … it is not a DAO rescue"); REC-03 residual (1) and (6) `06:436`; LIVE-01 `10:146-148`; and the
review's question (1)/(3): the action executes without any fresh trigger evaluation, which is "acting
without the objective trigger" in the execution half of the rule.

**Evidence.** `08:758-813` (GOV-04 clauses (a)–(g)), `08:279` and `09:177` (`govResumeState` is
`none/queued`), `01:220` ("no recovery-completion record"), `06:412` (Repeated action), `06:436`
(residuals), `06:401` (trigger), `06:404`, `06:406`; `02:539-542` (mutual exclusion with the rotation);
`04:163`, `05:198`, `05:274`, `02:180-181` (generation binding on the acceptance path); `09:159-170`
(withdrawn pricing); D-15.

---

## Finding G-2 — High: `T_GOV_RESUME` cannot be an exit window for the users the resolution discards, because an exit that needs new settlement and an execution that needs no progress are mutually exclusive

**Severity: High.** One-line rationale: GOV-04(d)'s MUST — "long enough that **every user** can exit via
MEM-15 before execution" — is unsatisfiable for the class at risk: value above the last accepted
checkpoint has no L1-provable claim at all, and value at or below it is releasable only against a
**withdrawal root** at an epoch boundary, which exists only once settlement has advanced — and settlement
advancing voids the queued entry, so the users who could exit never face the resolution and the users the
resolution discards were never able to exit, whatever the timelock length.

**Exact rule / missing rule.**
- `08:783-789` (GOV-04(d)): "`T_GOV_RESUME` MUST be long enough that a user who observes the queued entry
  can complete the exit of MEM-15 … before the action executes." `06:404` (REC-02 *Timelock*) says "**every
  user**"; the page header repeats it (`06:26-31`), as do HALT-04 `06:225-226`, LIM-01's A-GOV-2 row
  `10:319`, and the index `index.html:560`.
- `03:350` MEM-15(1) covers only signals "included in the L2 state **at or below** the head height of the
  latest L1-accepted checkpoint", and `03:353` MEM-15(4): "A holder whose value sits in an L2 balance, or
  whose L2→L1 message is above the latest accepted checkpoint, has **no L1-provable claim** and cannot
  create one while production is halted … it is **not repaired** here."
- `04:813-819` MSG-03: a release "MUST require a **withdrawal root** (L1-13) whose `stateRoot` covers the
  signal at a height not below the height at which the signal was stored, plus the delay
  `WITHDRAWAL_DELAY` measured **from that root's `l1BlockNumber`**", and the design "MUST also disclose
  that a settlement halt delays withdrawals — **indefinitely** if no trigger fires and governance never
  queues or executes the action".
- `04:442` L1-13(1): "the **epoch-boundary checkpoint** is the L1-07 record whose height equals
  `h_last(e)`"; a withdrawal root is such a checkpoint, written by `land`. `04:444` L1-13(3): the attach
  path `attestWithdrawalRoot(height, …)` attests the **recorded `statementHash`** of an existing checkpoint
  and "MUST NOT write a checkpoint". `04:446` L1-13(5): with fewer than `k` families no new root forms and
  the wait is unbounded.
- `08:790-795` GOV-04(e) (and `06:406`): acceptance of an extending batch **voids** the entry.
- `10:149-152` LIVE-01 nevertheless states, "Independent of every clause above", that every message at or
  below the checkpoint "stays withdrawable on L1 with no new L2 block, no consensus participation, no
  quorum and no validator cooperation"; MEM-15's own tag concedes the debt: "The reconciliation of MSG-03's
  'a settlement halt delays withdrawals — indefinitely' sentence with this rule is owed by page 04"
  (`03:356`), and it is still owed.
- **Missing rule:** an honest statement that the timelock is an exit window only for value already covered
  by an existing withdrawal root, plus a release path that does not require settlement to advance (or an
  explicit statement that no timelock length can protect the discarded class).

**Assumptions.** None. No adversary, no parameter choice, no governance failure. `E_EPOCH = 1,800 s`
(`02:439-440`) and `WITHDRAWAL_DELAY` unmeasured (`09`), so the argument is structural, not numeric.

**Concrete attack trace (no adversary).**
1. Let `H` be the last accepted checkpoint and `R` the last existing withdrawal root (an earlier epoch
   boundary, `R < H`). A user's signal sits at height `h` with `R < h ≤ H` — the ordinary case for anyone
   who bridged during the current epoch (up to 900 blocks / 30 min of history).
2. Settlement stalls (`06:401`); `H` stops advancing. Governance queues the resolution against `H`.
3. The user's release path is a root at height `≥ h`. The candidate is the next epoch boundary
   `h_last(e) ≥ h`, which is not yet a checkpoint; forming it requires `land` to accept batches up to that
   height — settlement must advance. The attach path cannot manufacture it (`04:444`: it attests a
   recorded statementHash and writes no checkpoint).
4. If settlement advances, the entry is void (`08:790-795`) and nothing is discarded. If it does not
   advance, no root forms and the user cannot release; the entry executes and discards `h`. **The two
   branches are complementary, so the exit window cannot be the thing that creates the exit.** The rule's
   claim is false for every user it is written to protect, for every value of `T_GOV_RESUME`.
5. The case is stronger still for a user whose value is an unmessaged L2 balance above `H`: MEM-15(4)
   gives no claim, and if production is halted the user cannot even *create* a withdrawal signal, because
   the signal is an L2 transaction that would land above `H`.
6. After execution the value above `H` is rewound, the disclosed remedy is resubmission at the user's own
   risk (`06:409`, `06:413`), and the guarantee class presented in GOV-04(d)/A-GOV-2 — "the timelock gives
   every user the exit window of MEM-15" — was never available.

**Inside / outside the claimed fault model.** **Inside**, with no adversary at all: this is the design's
own trigger and its own remedy, in the exact scenario the remedy exists for.

**Attacker resources and cost.** None. The harm is that the false protection sizes `T_GOV_RESUME`, is
carried as Open under falsifier (c) ("a **measured** worst-case time to exit via MEM-15 exceeds the
recorded `T_GOV_RESUME`", `06:437`) as if it were a timing question, and is repeated in four artifacts.

**Requirement / fixed decision affected.** **D-15**'s timelock clause and its rationale ("Users are
protected by the existing exit guarantee, not by a recovery mechanism"); GOV-04(d); REC-02's *Timelock*
row; REC-03 falsifier (c) and residual (7) `06:436-437`; MEM-15(4)/LIVE-01/MSG-03/L1-13 consistency.
Round-5 findings F1/F2 are unfixed and are now load-bearing for a fixed decision.

**Evidence.** `08:783-789`; `06:404`, `06:406`, `06:437`, `06:26-31`; `03:350`, `03:353`, `03:356`;
`04:442-446`, `04:813-819`; `10:149-152`, `10:319`; `index.html:560`; D-15; R5T liveness F1/F2.

---

## Finding G-3 — High: the anchor certificate's generation is unspecified, and the reference reading makes the first epoch-opening batch after a resolution unprovable

**Severity: High.** One-line rationale: PRF-05(ii)(a) verifies `B_anchor`'s certificate "under the same
signature, distinct-signer and quorum checks as PRF-04(i)–(iii)", and PRF-04(i) requires every
contributing vote's generation to equal **the journal's** `recoveryGeneration` — the post-increment value —
while `B_anchor` is the restored checkpoint block and its certificate was necessarily signed under the
superseded generation, so on the reference reading the resumed chain cannot prove the batch that opens
the next epoch; on the charitable reading the rule that stops a certificate from being presented under a
different generation is silently dropped on the anchor path.

**Exact rule / missing rule.**
- `05:283` (PRF-05(ii)(a)): the header at `f` MUST carry `epoch_anchor` and the guest MUST recompute it
  "from the anchor header `B_anchor` and the closing epoch's commit certificate it verifies — the
  certificate MUST be a valid epoch-`(e−1)` commit certificate for `B_anchor` under the L1-pinned
  `anchorSetRoot` and `anchorSetTotalVotingPower`, **under the same signature, distinct-signer and quorum
  checks as PRF-04(i)–(iii)**, with `B_anchor` in place of the head block and the closing epoch's set in
  place of the batch epoch's set".
- `05:251` (PRF-04(i)): "The reconstructed vote bytes include the signed `recovery_generation` … and the
  guest MUST require **every contributing vote's generation to equal the journal's `recoveryGeneration`**
  and the head header's generation."
- `02:353` (CONS-10(6)): `cert_hash = keccak256(abi.encode("TAIKO_ETNA_CERT_V1", chainId, epoch, height,
  round, recovery_generation, …))`; `02:348` makes `epoch_anchor` a commitment to `cert_hash(e)` of
  `B_anchor`'s certificate. So the opening header **commits to the anchor's own (old) generation**, while
  the PRF-04(i) analogue demands the journal's (new) one.
- `08:774-777` (GOV-04(c)): execution "increments `recoveryGeneration` by exactly one". `02:85-87`
  (CONS-02): a vote whose generation disagrees with "the recovery generation the Inbox holds" "is invalid
  regardless of its signature" — so no honest validator could have signed the anchor under the new
  generation.
- `06:444` (REC-04(1)) and `04:217` (L1-06): the resumed chain begins at `resumeHeight = lastLandedHeight
  + 1`; PRF-05 forces any batch containing `h_last(e−1)` to end at `h_last(e−1)`, so a checkpoint is
  routinely an epoch boundary and the restart height routinely opens an epoch.
- `05:196` (PRF-02(4)) still describes the withdrawn recovery-restart form (see G-7) and lists only
  `setVersion`, `setVersionBlock`, `anchorSetRoot`, `anchorSetTotalVotingPower` as the L1-derived anchor
  inputs: **there is no journal or L1-derived input for the anchor certificate's generation.**
- **Missing rule:** "the anchor certificate is judged under its own signed generation — the generation
  carried by the certificate, with every contributing vote's generation equal to it — and not under the
  journal's current generation."

**Assumptions.** None beyond the rules; no adversary. `B_anchor` is the restored checkpoint block
(`06:444-445`), so the case is the ordinary post-resolution restart, not an exotic one.

**Concrete attack / failure trace.**
1. The last accepted checkpoint is `H = h_last(e−1)` (a batch that contains the epoch's last height can
   only end there).
2. A settlement stall persists past `T_STALL_GOV`; governance queues and any account executes the
   resolution: `g → g+1`, `resumeHeight = h_first(e)`. The next accepted batch therefore starts at an
   epoch boundary and must carry `epoch_anchor`.
3. `B_anchor` is the restored checkpoint block; its certificate was signed by epoch-`(e−1)`'s set under
   generation `g` (the only generation then current).
4. A guest following PRF-05(ii)(a)'s "same checks as PRF-04(i)" applies the generation equality against
   the journal's `g+1` to the anchor's votes; they carry `g`, so the check fails, the anchor certificate
   is not verified, `epoch_anchor` cannot be recomputed, and the batch is unprovable. Every
   epoch-opening batch after the resolution has this shape, so the restarted chain cannot cross its first
   epoch boundary — the exact case the restart rule exists for.
5. The alternative implementation takes the anchor's generation from the witness certificate (so
   `cert_hash` recomputes), but then it must *also* require the anchor's votes to carry that same value;
   no rule says so, and the carried value is not one of PRF-02(4)'s L1-derived anchor inputs. The equality
   that PRF-04(i) exists to enforce — "a certificate assembled under a different generation cannot be
   presented as this batch's finality evidence" — is then witness-supplied on the anchor path.
6. Either way the specification leaves the choice to the implementer in the one value that decides whether
   the resumed chain can settle at a boundary; CONS-03 `02:115-122` calls exactly this split between L2
   acceptance, guest acceptance and L1 acceptance a protocol defect.

**Inside / outside the claimed fault model.** Inside (specification/engineering defect on the honest
restart path; no adversary, no assumption broken).

**Attacker resources and cost.** None. If the charitable reading is implemented with a witness-supplied
generation and no vote-equality check, the residual is an unaudited gap in the round-4 fix rather than an
immediate attack: forging the anchor still needs >2/3 signatures over votes that hash to the committed
`cert_hash`, which the real signers did not produce under a different generation.

**Requirement / fixed decision affected.** D-15 ("validators sign the new generation"; the restart must
work); REC-04; PRF-05(ii), PRF-04(i), PRF-13; CONS-10(6)/`cert_hash`; the round-4 finding that "the
generation bound the proof and not the history".

**Evidence.** `05:283`, `05:251`, `05:196`; `02:348`, `02:353`, `02:85-87`; `06:444-445`; `04:217`;
`08:774-777`.

---

## Finding G-4 — Medium: the resume-only claim is true of the action's calldata, but the trigger and the exit window are governance-set immutables with no protection for future entries

**Severity: Medium.** One-line rationale: `T_STALL_GOV` and `T_GOV_RESUME` "change only by upgrade"
(`08:356-361`), GOV-03(e)/GOV-04(d) protect only the remaining term of an entry **already queued**, and the
only constraints on new values are derivation obligations with no enforcement point — so one ordinary
upgrade can move the trigger to its conforming minimum (a late proof becomes a "settlement stall") and the
window to its conforming minimum for all future entries, while REC-02's *Resume-only* row claims
"Governance chooses … no configuration value" and no falsifier covers it.

**Exact rule / missing rule.**
- `08:356-361`: "Protocol parameters (… and the stall-resolution parameters `T_STALL_GOV` and
  `T_GOV_RESUME`) are **constructor immutables** of the settlement implementation, not storage: they change
  only by upgrade and consume no gap slot."
- `08:783-789` (GOV-04(d)): "**An upgrade may not shorten the timelock of an entry already queued**: a
  change to `T_GOV_RESUME` applies only to entries queued after it." `08:747` (GOV-03(e)) likewise
  protects "a queued entry … its remaining timelock and the generation" only.
- `06:401` and `09:175`: the sole constraint on `T_STALL_GOV` is the *value* relation "strictly larger
  than the D6 envelope" (registered as `T_STALL_GOV > T_PROOF_ENVELOPE + T_SETTLE_PIPELINE`); `09:176`
  and `06:404`: the sole constraint on `T_GOV_RESUME` is the unmeasured "long enough that every user can
  exit" claim (finding G-2). Nothing in the queue path re-checks either relation.
- `06:405` (REC-02, *Resume-only; no discretion*): "Governance chooses **nothing**: no state, no
  checkpoint, no height, no validator set and **no configuration value**."
- `06:437` REC-03 falsifiers (b) and (h) cover the action's own parameters and an already-posted entry;
  `10:319` (A-GOV-2) discloses "opportunistic use" of a **genuine** stall only.
- **Missing rule:** a change to `T_STALL_GOV` or to `T_GOV_RESUME` for future entries is either forbidden
  below a registered floor that is enforced, or explicitly named as a governance discretion in REC-02's
  *Resume-only* row, REC-03's falsifiers and A-GOV-2.

**Assumptions.** One DAO upgrade (a rules change, which GOV-02 `08:741` requires to be published as such)
and then the ordinary queue/execute path. A captured DAO is F2 and disclosed; the defect here is the
*honest-upgrade* boundary and the completeness of the "chooses nothing" claim.

**Concrete trace.** (1) An announced upgrade lowers `T_STALL_GOV` towards its floor and `T_GOV_RESUME`
towards the fastest conforming exit, both values individually conforming to the registered relations.
(2) Thereafter a single late proof makes the "objective settlement stall" true, and the exit window is the
minimum the design permits. (3) Governance queues and any account executes: an unfavourable provisional
range is discarded with no parameter outside the registered constraints, and no rule reports this as
anything other than an ordinary execution of GOV-04. The trigger is still objective; what is governance
policy is what "stall" means and how much exit time the window buys.

**Inside / outside.** Inside the honest-upgrade path; outside the *attack* fault model only in that it
requires a DAO transaction, which GOV-01 grants and GOV-02 requires to be disclosed. It is not covered by
the F2 disclosure, which speaks of a rules change that rewrites the rules, not of a conforming parameter
move that weakens the protection the rules are supposed to provide.

**Attacker resources and cost.** One upgrade (DAO), then gas.

**Requirement / fixed decision affected.** D-15 (the trigger and the timelock are the protection);
REC-03 falsifier completeness; GOV-04(d); REC-02 *Resume-only*; A-GOV-2.

**Evidence.** `08:356-361`, `08:745-757` (GOV-03(e)); `08:783-789`; `06:401`, `06:404`, `06:405`, `06:437`;
`09:175-176`; `10:319`.

---

## Finding G-5 — Medium: the certificate object of CONS-05 contradicts the encoding table on the same page about the generation field

**Severity: Medium.** One-line rationale: CONS-05 defines the certificate as
`(chain_id, epoch, H, R, B, set_root(epoch), signers, signatures)` and then makes its validity depend on
`recovery_generation`, while the encoding table on the same page carries `recovery_generation:u64` "so
the acceptance rule can reject a superseded generation without re-deriving it" — so the object over which
the round-4 generation fix is defined is ambiguous in exactly the field that decides whether a discarded
branch is void, and two conforming implementations can judge one certificate under two generations.

**Exact rule / missing rule.** `02:180-181` (CONS-05): "A **commit certificate** at `(H,R)` for block id
`B` is `C = (chain_id, epoch, H, R, B, set_root(epoch), signers, signatures)`. It is **valid** iff
`epoch = epoch_of(H)`, `set_root(epoch)` equals the L1-committed set root …, **`recovery_generation`
equals the generation the Inbox holds at acceptance and the generation signed by every contributing
vote** …, and `quorum_block(Q, B)` holds". Against it: `02:41-42` (encoding table, same page):
`CommitCertificate` = "chain_id:u256, epoch:u64, **recovery_generation:u64**, height:u64, round:u32,
block_id, set_root:bytes32, signers:bytes, signatures:bytes[] … the field is carried so the acceptance
rule can reject a superseded generation without re-deriving it". Also `02:245-246` (CONS-08(1)): "every
vote and certificate also carries the recovery generation"; `02:353` (`cert_hash` preimage includes it);
`06:407`; `05:47`; `04:163` (L1-05 row 31). **Missing rule:** one field list for
`CommitCertificate`, and CONS-05's validity predicate stating where the generation is read from.

**Assumptions.** None. **Consequence:** a standalone certificate — gossiped, served to a lagging node,
used as evidence, or presented as `B_anchor`'s certificate for the `epoch_anchor` recomputation — does not
determine its own generation. An implementation that takes it from the current Inbox state rejects a
valid historical certificate (fails closed but stalls the epoch handoff); one that takes it from the
certificate's own field is relying on a field CONS-05's object does not have; one that takes it from the
witness is not checking the equality CONS-05 states. This is not a forgery path (the votes are still
signature-checked over reconstructed bytes), but it is the definitional ambiguity that CONS-03
`02:115-122` classifies as a protocol defect when it splits client, guest and L1 acceptance.

**Inside / outside.** Inside (specification defect; no adversary). **Cost:** n/a.
**Requirement / fixed decision affected.** D-15's signed-generation binding; CONS-05/CONS-08/CONS-10
consistency; the round-4 fix.
**Evidence.** `02:41-42`, `02:180-181`, `02:245-246`, `02:353`; `05:47`; `06:407`; `04:163`.

---

## Finding G-6 — Medium: the generation scoping reaches the lock rule, the uniqueness rule and the conflict predicate, but not CONS-05's halt sentence

**Severity: Medium.** One-line rationale: "a node that … holds a **conflicting finalized block at H** …
halts (CONS-15) and MUST NOT silently adopt the other branch" carries no generation qualifier, although
every other halt and conflict rule was generation-scoped in this snapshot; a node that had PoS-finalized
the range that is later discarded can read the sentence literally and refuse to adopt the restored
checkpoint — the R5T-D2-01 harm class, closed only by reading "finalized" through CONS-05's own
generation-scoped validity clause.

**Exact rule / missing rule.** `02:188-190` (CONS-05, last sentence): "A node that instead holds a
conflicting lock at `H` (CONS-04) or a **conflicting finalized block at `H`** has evidence that the
assumptions failed; it halts (CONS-15) and MUST NOT silently adopt the other branch." Contrast the
scoped rules: `02:157` (CONS-04(2): a lock formed under a superseded generation "is void at every
discarded height … neither constrains a vote under the new generation … and is **not** a halt condition");
`02:372-378` (CONS-11: a pair whose signed generations differ "is **not** a conflict"); `02:402`
(CONS-12: uniqueness scoped to a generation, superseded certificates void at acceptance); `02:512-514`
(CONS-15(2): the halt trigger is a certificate conflicting with the lock "**under the current
generation**"); and the restart duty that says the opposite of a halt: `06:143-145` (HALT-02: "a node must
adopt it, must not treat a discarded block above it as finalized"), `06:54-58` (REC-01(c)).
**Missing rule:** qualify CONS-05's halt sentence with "under the current generation", as CONS-15(2) does.

**Assumptions.** An honest node that finalized heights of the range that is later discarded — the ordinary
case, since the discarded range was certified by more than two thirds under the old generation.

**Trace.** (1) Heights `H+1 … T` are PoS-finalized under generation `g`; the node holds those certificates.
(2) A resolution executes; generation `g+1`; the range is discarded and re-produced. (3) The node receives
the new-generation block at `H+1` and must adopt it (`06:143-145`). (4) It still holds the old certificate,
so `02:188-190` read literally says it holds "a conflicting finalized block at `H+1`" and must halt and
MUST NOT adopt — the restarted chain loses exactly the nodes that hold the discarded history. The intended
reading is available (CONS-05's validity clause requires the *current* generation, so the old certificate
is not valid and the block is not "finalized" any more), but it is not the sentence that decides, and the
same literal-reading risk is what round 5 recorded against the retired-height design.

**Inside / outside.** Inside (rule text; no adversary). **Cost:** none.
**Requirement / fixed decision affected.** D-15's restart; HALT-02; CONS-15; CONS-12/INV-01.
**Evidence.** `02:188-190`, `02:157`, `02:372-378`, `02:402`, `02:512-514`; `06:143-145`, `06:54-58`.

---

## Finding G-7 — Low: PRF-02(4) still describes the withdrawn recovery-restart form as a live case

**Severity: Low.** One-line rationale: PRF-02(4) states that the anchor fields are read "except in the
**recovery-restart form (b)**, where the two anchor fields are read from L1 as usual but **no certificate
is judged against them** and the header's `epoch_anchor` is recomputed from
`prevHeight`/`prevBlockHash`/`prevStateRoot`/`firstHeight` (`REC-04`(3))" — but PRF-05(ii)(b) explicitly
declares that form withdrawn, REC-04(2) withdraws the recovery anchor, and REC-04(3) no longer defines any
anchor rule (it is now "why a discarded block still cannot be landed"), so a reader implementing the
anchor recomputation from PRF-02(4) is sent to a formula no live rule defines.
**Exact rule / missing rule:** `05:196` (PRF-02(4)) versus `05:283` (PRF-05(ii)(b), "withdrawn under user
decision D-15"), `06:445` (REC-04(2)) and `06:446` (REC-04(3)). Missing rule: none security-critical;
delete the parenthetical and cross-reference PRF-05(ii)(a).
**Assumptions / trace / cost:** none. **Affected:** the D-15 sweep's completeness; PRF-02/PRF-05
consistency. **Evidence:** `05:196`, `05:283`; `06:443-446`.

---

## Checked, and holds (not re-listed)

- **The generation is present where the ordinary path needs it, and a stale generation cannot be
  accepted.** Vote bytes carry it and it is signed (`02:35-37`); the header carries it and it is inside
  the block hash (`02:369`, CONS-10(7)); the journal carries it as an **L1-derived** value the contract
  never takes from the submitter (`05:197-198`, `04:163`); the guest requires three-way agreement
  (`05:274`, `02:180-181`); `land` rejects any range that does not extend the checkpoint "at every
  generation" (`04:217`); aggregation adds no second statement (`05:530-531`). I re-attacked the
  stale-acceptance path and could not break it: to land a discarded branch one would need >2/3 of the set
  to have signed the new generation over that branch, which CONS-01(vii)/CONS-02 forbid and the header
  bytes make non-repudiable. The residual defects are definitional (G-5), on the anchor path (G-3) and in
  the halt sentence (G-6).
- **Lock rule and conflict predicate are coherent under generation scoping.** A lock formed under a
  superseded generation is void, requires no PoLC and is not a halt condition (`02:157`); re-signing the
  same `(H,R)` under the new generation is expressly not equivocation (`02:95-101`, `02:378`); a
  differing-generation pair is not a conflict and a same-generation pair still is (`02:372-378`). The
  round-4 "locks survive recovery" and round-5 R5T-D2-01 lock mechanism do not return; the surviving
  ambiguity is G-6.
- **Void-on-progress in the direct case (question 3).** An accepted extending batch voids the entry and any
  account may cancel it (`08:790-795`); a batch accepted and then reorganised out below finality never
  took effect for L2 (SYS-02, `01:220`), and L1-06 forbids any function — "including an upgrade
  initialiser, the stall-resolution action, or any governance call" — from decreasing `lastLandedHeight`
  or replacing a record at or below it (`04:221`, "with no exception"); GOV-03(e) requires an upgrade to
  carry a queued entry, its remaining term and the generation unchanged (`08:747`). I could not construct
  a resolution that executes *after* the checkpoint advanced. The failure is the mirror one: execution
  with no consumption and no fresh trigger (G-1).
- **Resume-only in the action's effect (question 1).** No calldata names a height, hash, checkpoint,
  range, subset or beneficiary (`08:766-773`); `resumeHeight` is derived from L1 state (`08:774-782`);
  history at or below the checkpoint is untouchable (`06:37-86`, `04:216-224`); the resumed heights are
  judged under the L1-committed set versions the schedule assigns (`08:805`) and the rotation of CONS-16
  is mutually exclusive with a queued entry (`02:539-542`). I found no governance path that *chooses* a
  state, height, checkpoint or validator set. The discretion that exists is G-4 (parameters) and G-1
  (repetition), not the effect.
- **The withdrawn mechanism's own defects do not return.** R5T-D2-01 (under-sized bundle), R5T-D2-02
  (bond actor mismatch), R5T-D2-04 (L1 cannot verify Ed25519), R5T-D2-06 (interface/bond custody) and
  R5T-D2-07 are moot with REC-02–REC-04's machinery and its parameters tombstoned (`06:389-428`,
  `09:156-170`); the replacement accepts no bundle, verifies nothing on L1 beyond its own record, has no
  bond and pays nobody. In particular I re-checked "can a recovery-like action be selective?": the discard
  is the whole range by construction, and no per-range claim exists.

## Answers to the five questions this review was charged with

1. **Is the resume-only constraint real — can any governance action, upgrade or sequence of them choose a
   state, height, checkpoint or validator set, or act without the objective trigger?** The *effect* is
   genuinely resume-only: nothing in the action's calldata or in the queue record names a state, height,
   checkpoint, subset or set, `resumeHeight` is derived, and the boundary at or below the checkpoint is
   untouchable from every path I traced. But the constraint fails at its two ends. (i) *Acting without the
   trigger:* the trigger is evaluated only when the entry is **queued**; execution is permissionless and
   re-checked against nothing, and the entry is never consumed, so the same entry executes again and again
   with no fresh trigger (G-1). (ii) *Choosing by parameter:* the trigger's threshold and the timelock are
   governance-set immutables whose only constraints are unenforced derivation obligations, and only an
   already-queued entry's remaining term is protected, so one ordinary upgrade can redefine what "stall"
   means and how much exit time the window buys for all future entries (G-4). Governance cannot choose a
   *state*, but it can choose the *policy* under which the action that discards the provisional range
   becomes available.
2. **Is the generation binding complete end to end?** On the object list: vote ✓ (signed, `02:35-37`),
   precommit bytes = vote bytes ✓, header ✓ (signed into the block hash, `02:369`), journal ✓ (L1-derived,
   `05:197-198`, `04:163`), certificate — carried by the encoding table (`02:41-42`) but **omitted from
   CONS-05's own tuple** while its validity predicate depends on it (G-5). On the rules: no acceptance
   path, lock rule or conflict predicate that I could satisfy under a **stale** generation — the L1
   contract derives the generation itself, the guest's three-way equality closes the vote/header path, and
   contiguity rejects non-extending ranges at every generation. Two holes remain, and both are on the
   *anchor* side: the anchor certificate's generation is unspecified and the reference reading makes the
   first post-resolution epoch-opening batch unprovable (G-3), and CONS-05's halt sentence can be
   triggered by a stale-generation certificate because it alone was not generation-scoped (G-6).
3. **Does void-on-progress plus permissionless cancellation prevent a resolution from executing after the
   chain has resumed, including reorg and upgrade cases?** Yes for the direct case, and I could not break
   it: an accepted extending batch voids the entry (`08:790-795`); an acceptance reorged out below
   finality never took effect for L2 (SYS-02/`01:220`); L1-06 forbids any path, including an upgrade, from
   lowering or rewriting the checkpoint (`04:221`); GOV-03(e) carries a queued entry and its generation
   through an upgrade unchanged (`08:747`). Two caveats: (a) "resumed" is defined by *settlement*, not
   production — a chain producing normally while settlement lags is still discarded by rule, which is
   disclosed (`06:410-413`); (b) the rule is one-sided: there is no consumption and no upper bound on
   executability, so the entry remains live *after* execution and can be re-run indefinitely (G-1), and an
   entry left in the stored `queued` state also blocks a later entry and the CONS-16 rotation
   (`02:539-542`).
4. **Is the timelock genuinely an exit window?** No (G-2). Every user who can exit inside the window is a
   user for whom the entry is voided by the settlement progress that made the exit possible; the users the
   resolution discards are exactly the users who cannot exit — above the last accepted checkpoint they have
   no claim at all (MEM-15(4)) and cannot even create one while production is halted, and at or below it
   they need a withdrawal root at a **newly settled** epoch boundary (MSG-03, L1-13(1)-(3)). No value of
   `T_GOV_RESUME` changes this, so REC-03's falsifier (c) — a *measured* exit time exceeding the recorded
   window — measures a quantity that is not the operative one, and the "every user" MUST in GOV-04(d),
   REC-02's *Timelock* row, HALT-04, A-GOV-2 and the index is false as written. What happens if they
   cannot exit: the value above the checkpoint is discarded and must be resubmitted (disclosed), with no
   protocol compensation (`06:409`, `06:413`, ECON-11).
5. **What is the honest residual of a captured or absent governance, and is it disclosed rather than
   assumed away?** Largely disclosed and unusually honest: A-GOV-2 `10:319` states there is no protocol
   bound on governance liveness, that a captured or coerced governance can wait for a genuine stall and
   have an unfavourable provisional range discarded, and that no rule detects, prevents or repairs the
   capture; GOV-02 `08:737-744` names it failure class F2 and requires a rules change to be reported as
   one; REC-03 residual (1) and (6) repeat it. Three gaps: (i) the disclosure covers opportunistic use of
   a *genuine* stall, not the parameter-level nullification of the trigger and the exit window for future
   entries (G-4); (ii) it does not cover the case where an honest, live governance queues the required
   remedy and any account turns it into a permissionless settlement-denial loop (G-1); (iii) the residual's
   own mitigation column repeats the false "every user can exit" claim (G-2). The residual is disclosed;
   what is *not* disclosed is that the fixed decision's protection is weaker than the sentence that
   carries it.

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 1 | G-1 (unconsumed GOV-04 entry: re-executable by any account with no fresh trigger; the remedy becomes a generation-churn denial of settlement) |
| High | 2 | G-2 (the timelock cannot be the exit window for the class the resolution discards) · G-3 (anchor-certificate generation unspecified; the first post-resolution epoch-opening batch is unprovable on the reference reading) |
| Medium | 3 | G-4 (trigger and timelock are governance-set immutables, unprotected for future entries) · G-5 (CONS-05's certificate tuple omits the generation the encoding table carries) · G-6 (CONS-05's halt sentence is not generation-scoped) |
| Low | 1 | G-7 (PRF-02(4) still describes the withdrawn recovery-restart form) |

**Strongest attack:** G-1. Governance does the one thing D-15 asks of it — queue the stall resolution
during a genuine settlement stall — and from that moment any account can call the permissionless
`execute` entry point over and over, because nothing consumes the entry, the checkpoint does not advance
and the timelock predicate is one-sided. Each call increments `recoveryGeneration`; each increment voids
every certificate and proof of the only generation the Inbox will accept; a proof takes ~30 minutes to
produce, so no batch can ever land again while the attacker pays gas. The chain cannot resume, no new
checkpoint means no new withdrawal root, and the "resume-only" remedy is a permanent settlement-denial
lever. No bond prices it (the bond was withdrawn with D-15) and no rule forbids it.

**Inside the fault model?** Yes — G-1, G-2 and G-3 are all inside. G-1 needs no assumption failure, no
stake and no bond: it needs one honest governance queue (the remedy itself) and one L1 account with gas.
G-2 needs no adversary at all. G-3 needs no adversary at all.
