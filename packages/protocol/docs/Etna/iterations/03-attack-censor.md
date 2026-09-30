# ETNA red-team round 3 -- CENSOR AND MONOPOLIZE

## Model

Running as Claude Opus 5.5 (model id claude-opus-5-5), as requested (opus).

## Method

Read the design site fresh at commit 8cc029e (index, roles, sequencing, preconf, landing, slashing,
forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies,
frame-transactions, limitations, glossary), 01-threat-model.md, README.md, and the learn/ site.
Re-simulated committee composition under the revised walk with a script. Each finding below is an
attack trace against the text as written; findings are appended as they are completed.

Simulation script: scratchpad `phase4/sim3/walk.py` and `curve.py` (holder walk per sequencing §5: first five
distinct owners over 64 tries; committee per §8 revised: first 32 distinct seats of the pool that excludes every
seat of the primary's owner and the drawn seat of each backup; 20,000 to 200,000 terms per case).

## Findings

### C1. Veto-then-takeover: a one-third single-seat cartel holds 63 % to 87 % of all terms with no slashable signature; the cost curve "share X costs X·H/(1−X) seats" fails above about 25 %

**Severity: High.** R6, TH9, TH10, TH8; entrant exclusion. Inside the stated bound: the veto needs m − Q(m) + 1 = 11
of 32 slots, below T11 ("fewer than Q ... collude silently"); the design itself analyses c = 0.33 (slashing §5).

**Actors.** Honest 5 owners × 8 seats; cartel 20 addresses × 1 seat (420k TAIKO). Share 0.333.

**Trace (term t, honest primary P0; seconds from termStart).**
1. S(t): committee = 32 of the 48 seats left after P0's 8 seats and the backups' drawn seats; P(cartel ≥ 11) = 0.70.
2. 0 s: P0 publishes h+1; 21 honest seats attest, the cartel stays silent (unslashable); no C(h+1); P0 holds after h+2.
3. 5 s: every attester truthfully sees no certificate for 5 s and signs TO(t, 0, TIMEOUT, lock h); VC(t, 0) at ≈ 5.4 s.
   No cartel key signed two locks (S3c) or attested above h (S3b).
4. Honest backups are timed out the same way (≈ 10.8, 16.2, 21.6 s) until the first cartel backup Hj, j ≤ 4, which
   produces the remaining 38 to 55 s, now attested by everyone.
5. The cartel's landing burns 50 TAIKO per timed-out honest view.

**Simulated term share** (cartel primary, or vetoed honest primary with a cartel backup):

| honest set | c = 0.20 | 0.25 | 0.30 | 0.333 | 0.40 |
|---|---|---|---|---|---|
| 5 × 8 | 0.20 | 0.32 | 0.69 | 0.87 | 0.98 |
| 40 × 1 | 0.20 | 0.26 | 0.45 | 0.63 | 0.88 |
| 6 × 8 | 0.20 | 0.35 | 0.66 | 0.80 | 0.95 |
| 25 × 8 | 0.22 | 0.34 | 0.52 | 0.64 | 0.85 |

The restated figure "a 10-seat cartel reaches 11 slots in about 9 %" (slashing §5, learn/09) is impossible (10 seats,
11 slots; simulated 0 %), and at c = 0.3 / 0.4 the veto rate is 0.28-0.49 / 0.82-0.93, not the binomial 0.36 / 0.79.

**Design text.** "Share X against H honest seats costs H·X/(1−X) seats (with H = 40: 50 % = 40 seats = 800k TAIKO,
90 % = 360, 99 % = 3,960)" (sequencing §12); "A party that pays the linear price holds what it paid for" (slashing §11).

**Cost / gain.** 50 % of terms costs ≈ 16 seats (320k TAIKO), not 800k. At c = 0.333 the cartel gains ≈ 770
terms/day (≈ 7.7 ETH at V_term = 0.01 ETH); the honest set burns ≥ 33,600 TAIKO/day and reaches the hard floor
(440k between buffer and floor) in ≈ 13 days without top-ups, then the cartel holds every term. A one-seat entrant
drawn as primary is vetoed in 54 % to 89 % of its terms (c = 0.33 to 0.4). Cartel cost ≈ 0.

**Fix.** Sign TIMEOUT only on leader silence: an attester that attested a valid block of (t, v) within TIMEOUT signs
no TIMEOUT for (t, v); a vetoed live leader's term closes by the penalty-free fallback, so the cartel can deny but
neither capture nor bleed. Or fix every view's coinbase to the primary. Restate the curve and tables from simulation.

### C2. The round-2 F1 fix did not propagate: two design pages still define the committee as excluding every holder by owner, and the learn site still puts no-committee mode below four seats

**Severity: Medium.** R6, R4, TH9 (a contradiction on the rule that round 2 rated High).

**Contradicting text (verbatim).**
- preconf.html:21 (§1, Objects and keys): "committee(t) (up to K = 32 seats, drawn from seats whose owners are not in
  the term's holder list)".
- roles.html:51 (Attester, Entry and exit): "every registered seat is eligible for the per-term committee of up to 32
  seats drawn by the cycle seed, excluding the term's holders".
- against sequencing.html §8 (normative walk): "skipping every seat of the term's primary holder (view 0, excluded by
  owner ...) and the specific seats of the backups (excluded by seat only ...)", and learn/02.
- learn/02-seats.html:29: "No-committee mode. Fewer than four eligible attester seats (for example at launch)"
  against K_MIN_CERT = 8 everywhere in design/ (the round-2 S10 fix corrected "below four" on index.html only).
- Removed S7 state survives in the storage summaries: interfaces.html:196 "recorded view changes, demands and
  answers, voided, last view-change hash" and bridge-migration.html:73 "demands, voided certificates".

**Trace (implementation built from the preconf page, which owns the certificate formats).** Honest set five 8-seat
owners (40 seats), cartel 10 single-seat owners (200k TAIKO, share 0.2). At S(t) the holder walk puts ≥ 4 honest
owners in H in about 92 % of terms (round-2 F1 simulation), so the preconf rule removes ≥ 32 honest seats and the
committee is ≤ 8 honest + 10 cartel (m ≤ 18, veto at m − Q(m) + 1 = 6): the cartel vetoes ≈ 92 % of terms and holds a
full quorum in ≈ 12 %, exactly the round-2 High, and with C1's takeover it captures most terms at 20 % share. The
normative sequencing walk gives 0 % veto for the same cartel (C1 table). An implementer of the learn page's
four-seat threshold certifies with m = 4 to 7 committees (2Q(m) − m = 2 to 3 double-signers behind "locked").

**Cost / gain.** Zero for the attacker; the consequence is which rule gets built. The design names no precedence
between the certificate page and the sequencing page for committee(t).

**Fix.** Replace both sentences with the sequencing §8 rule (or a link to it); fix learn/02 to K_MIN_CERT = 8; drop
"demands and answers, voided" and "demands, voided certificates" from both storage summaries; extend the round-2
grep list with "holder list", "term's holders", "four eligible", "demands".

### C3. announceLanding is missing from the "proven" forced-inclusion bound and from L3: a compliant censor delays a due entry to 112 min at zero cost, and Q + 1 colluders can land their "never landable" private blocks

**Severity: Low.** R7 / P5 (forced-inclusion bound), TH7, L3.

**Actors.** The FI page's own "compliant censor" (term holders plus a colluding quorum); 2,000 TAIKO announcement
bond, returned.

**Trace (s = 0 is the save).**
1. 0 to 2,160 s: the censor anchors 1,800 s stale; landings of earlier terms have T_floor < 300 and need not
   consume the entry (FI §9, legal).
2. Term t' starting at 2,160 s (end 2,220 s) must consume the entry; its FI block is certified, but the censor does not
   land. replaceableFrom = min(2,220 + 3,600, max(...)) + 300 = 6,120 s.
3. 6,100 s: the censor calls announceLanding(lastLanded.height + 1, end) with 2,000 TAIKO; replaceableFrom becomes
   6,720 s, so a ready forced batch is refused ("a forced batch is refused while a bonded landing announcement covers
   the head").
4. ≈ 6,700 s: the censor lands t' (it consumes the entry, as L8 requires); the announcement is covered, so the bond is
   returned. reportAbandoned against t' fails: no strictly later term can have landed before t' (sequential
   landing), so the outage gate is closed.
The entry lands at ≈ 112 min, 10 min past the proven bound, for gas only. The same step extends the absent-pipeline
figure (≈ 40 min) by 10 min for a 2,000-TAIKO forfeit (40 % of it paid to the forcer).

L3 variant: Q + 1 colluders that locked a private certificate hold C(n) and a recorded TERM_END VC with lock n. That is a
valid landing (A3: "landing the original stays valid"), so they can land their "private" blocks whenever they choose,
before or after replaceableFrom, and can stretch the stall to replaceableFrom + 600 s (≈ 75 min, not "35 to 65") by
announcing and then landing, at zero cost.

**Design text.** "landed ≤ s + 300 + 1800 + 120 + 3600 + 300 = s + 6,120 s (102 min), or the forced path plus proving
and inclusion (≈ 4 min)" and "proven (under T1, T3, one honest prover-lander) An entry saved at s is in an L1-landed
block by about s + 102 min against any sequencer and attester behaviour" (forced-inclusion §9, §16); "the private
blocks never land and their signers earn nothing" (preconf §6); L3 "35 to 65 minutes after the last landing".

**Cost / gain.** Gas only, for +10 min of landed-level delay; colluders choose when L3 ends and keep their blocks.

**Fix.** Restate the bound as s + 6,720 s (112 min) and the absent-pipeline and L3 figures with + LAND_CHAIN_GRACE,
or forbid announceLanding when the head FI entry has been due at T_floor of the first unlanded term for longer than
LAND_WINDOW. Replace "never land" with "land only if the colluders publish them".

### C4. MIN_OWNERS = 6 and 44 seats "enforced by initEtna" cannot be enforced there: the registry is empty when initEtna runs, and the same checklist says fewer seats are tolerated

**Severity: Medium.** R1, R4 (activation liveness), TH9; internal contradiction on the round-2 F1 fix.

**Text (verbatim).** bridge-migration §5: "the DAO's single upgrade transaction executes: deploy ... the Etna Inbox
implementation, then upgradeToAndCall(impl, initEtna(T0, lastFinalizedBlockNumber))"; migration table: "[U, T0 − FREEZE)
... Etna registry: allowed (effects future-dated)"; pre-T0 checklist: "at least MIN_OWNERS = 6 distinct owners and 44
registered seats (K + CAP + V_MAX, enforced by initEtna) ... with fewer, committees are smaller and their quorum scales
down ... and below 8 the no-committee regime applies". sequencing §8: "initEtna requires MIN_OWNERS = 6 distinct owners
and 44 seats".

**Trace.**
1. U: the DAO transaction upgrades the Inbox and calls initEtna in the same call. The registry storage and
   `register` exist only in the new implementation, so seatCount = 0 and owners = 0 at this instant.
2. Literal reading: initEtna's MIN_OWNERS check reverts; the upgrade can never execute. Etna cannot launch.
3. Implementer's repair A (move the check to activation, e.g. to the drain at T0, M1): Shasta proposing is closed from
   T0 − FREEZE; if fewer than 6 owners or 44 seats registered by T0 (for example because the whitelisted incumbents,
   who are the obvious first registrants, do not register), Etna never activates and L2 halts until the DAO rolls
   back, a DAO liveness dependency R1 forbids. A cartel of 6 addresses × 8 seats (960k TAIKO) can instead satisfy it
   alone; MIN_OWNERS is Sybil-trivial and certifies nothing about decentralisation.
4. Repair B (drop the check, as "with fewer, committees are smaller" implies): the round-2 F1 claim "a full committee
   exists with the primary owner excluded" is no longer guaranteed at launch, and nodes must publish m.

**Cost / gain.** No attacker cost; the migration either cannot run as written, or the fix chosen by the implementer
adds a launch halt lever (repair A) or silently drops the guarantee (repair B).

**Fix.** Make it a published launch condition, not a contract check: T0 is chosen by the DAO after observing ≥ 44
seats and ≥ 6 owners with effective activeFrom ≤ T0; initEtna does not check it; activation never depends on it (the
size-scaled quorum and no-committee mode already cover a small registry). State that MIN_OWNERS is a liveness sizing,
not an anti-monopoly guarantee.

### C5. Surviving constant contradictions: attester reward per landing versus per block, two per-term exposures, and 100 % versus 105 % registration bond

**Severity: Low.** R6 (economics), round-2 wording fix not propagated.

**Text (verbatim).**
- parameters.html:71 "ATT_REWARD_TOTAL | Slashing | gwei per landing | 6·10^9 (6) | ≈ 9 % of V_term; fixed total"
  and landing.html:162 "ATT_REWARD_TOTAL | TAIKO per landing | 6 | ... fixed total keeps the holder indifferent to
  bitmap size", against slashing.html:173 "ATT_REWARD_PER_BLOCK | gwei per landed block | 10^8 (0.1; 6 per full
  term) | ... per block so range splitting earns nothing" and the round-2 fix ("0.1 TAIKO per landed block rather than
  6 per landing").
- landing.html:161 "per-term exposure | 3,470 = 60 × R_BLK_MAX + SLASH_ABANDON + 5 × ATT_REWARD_TOTAL" against
  landing.html §5 and parameters §1 "60·R_BLK_MAX + 180·R_BLOB + SLASH_ABANDON + 60·ATT_REWARD_PER_BLOCK = 3,626".
- sequencing §2 "register(count) requires bond ≥ (seatCount + count)·B_SEAT" and roles §1 "bond ≥ seats × B_SEAT"
  against slashing §1 "registration and reactivation require 105 % of it".

**Trace (per-landing reading implemented).** An attester group holding ≥ Q slots of a term's committee lands the
term's 60 certified blocks as 60 one-block landings (sequential landing allows several per L1 block). Holder debit:
60 × 6 = 360 TAIKO attester share instead of 6, plus the per-block ramp; at 0.5 gwei a 1.5 M-gas landing costs
≈ 5 TAIKO, so each landing nets ≈ +1.5 TAIKO. Bounded by the buffer rule (reward debits stop at 1.05 × floor) and
by gas, so a nuisance drain, not a lever. With the 100 % registration reading, an owner registers at exactly its
floor, so every reward-type debit is refused from the start: third-party landers of its terms are never paid, and
its terms land only if it lands them itself (it pays S4a only when the outage gate opens).

**Cost / gain.** Small; the risk is which constant gets built.

**Fix.** Delete ATT_REWARD_TOTAL from both tables (keep ATT_REWARD_PER_BLOCK), fix the exposure row to 3,626,
state 105 % in register(count) and roles, and add "per landing", "3,470" and "≥ (seatCount + count)·B_SEAT" to the
grep list.

## What I tried and could not break

1. **Front-running an entrant's registration.** `register(count)` assigns indices in the contract ("a same-block
   append by an incumbent never reverts an entrant's transaction", sequencing §2), so a same-block append no longer
   reverts the entrant. Stealing or pre-binding the entrant's BLS key fails: the proof of possession covers (pubkey,
   owner, chainId) and "a key already bound is rejected", so a copied PoP verifies only for the entrant's owner.
   Pre-binding the entrant's sequencer-key address (no PoP) at most forces the entrant to generate a new key.
2. **Quorum capture (Q of 32) under the revised walk for private certificates or free attested reorgs.** Simulated
   P(cartel ≥ Q) ≤ 10^-4 at c = 0.333 and ≤ 8·10^-4 at c = 0.40 for all four owner structures, in line with the design
   table; the walk excludes the primary by owner, which never hands a single-seat cartel a quorum.
3. **Keeping the head FI entry skippable while landings continue (FI_SKIP gate).** Every landing, forced batches
   included, writes lastLanded.anchorTipTimestamp, and V5 keeps anchors within ANCHOR_MAX_AGE of block time, so the
   gap T − lastLanded.anchorTipTimestamp cannot reach 14,400 s while anything lands; a manufactured 4-hour stall is
   ended by the requester's own forced batch at replaceableFrom.
4. **Repeated RESUME V8 exceptions to postpone an FI.** "The exception is keyed on the opening object, so it is used
   at most once per void", and each void needs a forced or replacement landing, which itself consumes due entries
   (L8, forced batch rule 4).
5. **Chaining announceLanding to hold the forced path shut.** Deferral is "once per range (keyed on lastLanded)" and
   only "while replaceableFrom has not passed"; a forced landing leaves lastLanded.at untouched, so after it the
   predicate has passed and no new announcement is accepted; forced batches then chain. Net: one 600-s deferral (C3).
6. **Forcing no-committee mode to open a landing race.** The pool is A − seats(primary) − 4 ≥ 44 − 8 − 4 = 32 at
   launch, and a cartel can only add seats; no-committee landings are reserved to the sortition holder until its
   economic deadline anyway.
7. **Handoff ambush (W1) with the new vcHash keys.** The attacker's second VC shares (t, v, vcHash, kind) with the
   honest one, so 2Q(m) − m S3c signers are slashable and the honest VC is recorded first.
8. **Seed grinding to exclude an entrant from a cycle.** Rule D (DELAY_REG = 7,200 s) and RND3 freshness; poke() is
   public.
