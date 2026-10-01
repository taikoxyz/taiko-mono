# 01. Threat model

> What Etna must protect, from whom, under which assumptions. Every threat is stated against **today's** protocol (see `00-current-protocol-summary.md` for the code references) and then as a **requirement on Etna**. The withholding attack of the brief's Section 2.4 is treated as a first-class threat in §6. The red team is instructed to falsify every "Etna must" line in this file.
>
> Tags: **proven** (with a reference), **assumed** (assumption named), **open** (what would resolve it).

## Contents

1. [Assets](#1-assets)
2. [Actors](#2-actors)
3. [Trust assumptions, today and in Etna](#3-trust-assumptions-today-and-in-etna)
4. [Security properties](#4-security-properties)
5. [Threat catalogue](#5-threat-catalogue)
6. [The withholding attack, in depth](#6-the-withholding-attack-in-depth)
7. [Requirements-to-threats matrix](#7-requirements-to-threats-matrix)
8. [Out of scope](#8-out-of-scope)

---

## 1. Assets

| Asset | Where | Custodian today | Value at risk |
|---|---|---|---|
| A1. Bridged ETH | L1 Bridge escrow (`Bridge.sol:242`), L2 Bridge balance; documented invariant "combined balance ≥ 999,999,800 ETH" (`Bridge.sol:19-26`) | The Bridge proxies; released only against a signal proven through a SignalService checkpoint | Everything bridged. Stolen by anyone who can get a false checkpoint (state root) saved into a SignalService, i.e. by a false L1 finalization or a false L2 anchor. |
| A2. Bridged tokens | ERC20/721/1155 Vault escrows on L1; bridged-token mint rights on L2 (`ERC20Vault.sol:507-524`) | Vaults, same proof path as A1 | Same as A1. |
| A3. L2 state itself | Every L2 account | Whoever can finalize state on L1 (`Inbox.prove`) | A false state root finalizes theft of any L2 balance and corrupts every downstream bridge. |
| A4. Bonds | L1 Inbox ledger in TAIKO (`LibBonds.sol`) | Inbox; only debit is the late-proof settlement | Today zero on mainnet. In Etna: sequencer, attester and prover bonds are the primary economic security and a griefing target. |
| A5. Forced-inclusion fees | ETH held in the Inbox until consumption (`Inbox.sol:435-443`, `:710`) | Inbox; paid to whoever consumes the request | Small per request; voidable by `init3` today. |
| A6. L2 fee revenue | Coinbase share (75 % at the snapshot commit, 100 % on `main` since Proposal0026) and the Anchor's share of base fees (`Anchor.sol:141-142`) | Block builder; Anchor owner | Ongoing income; the incentive that makes sequencing rights worth capturing. |
| A7. Preconfirmation promises | Off-chain signed envelopes (`api.go:242-283`) | No custodian; not referenced on-chain | Users acting on soft confirmations (payments, exchanges, MEV). Today unbacked. |
| A8. Liveness of the chain | The ability to propose, derive and finalize | Whitelisted operators and provers, plus DAO/multisig for rotations | If lost, users cannot exit except through forced inclusion + proofs, both of which are also gated today. |
| A9. L1 proposal slot | The single `propose` allowed per L1 block (`Inbox.sol:590`) | First transaction to land | A wasted slot delays L2 by one L1 block; in Etna the landing slot for a batch. |
| A10. Governance keys | DAO controller `0x75Ba…` (L1), DelegateController (L2), `admin.taiko.eth` multisig | Token holders; multisig signers | Upgrade authority over every proxy; today also operational authority (§3). |

---

## 2. Actors

| Actor | Honest role | Capabilities an attacker in this role has | Etna role mapping |
|---|---|---|---|
| L2 user | Sends transactions; relies on preconfs and finality | Spam, mempool games, nothing privileged | user |
| Forced-inclusion user | Posts a blob and pays the fee (`saveForcedInclusion`) | Queue stuffing at 0.001 ETH+ each, up to 10 processed per proposal | forced-inclusion requester (anyone) |
| Operator (proposer + sequencer keys) | Builds and gossips 1-s blocks; proposes blobs once per L1 block | Withhold blocks, equivocate, censor, land arbitrary contents, MEV on private state, stall its epoch | **sequencer** (bonded, rotating) |
| Prover | Generates and submits aggregated proofs (`prove`) | Withhold proofs (no fallback today), submit forged proofs if a proof system is unsound, front-run other provers' submissions | **prover / lander** (permissionless) |
| L2 node operator | Derives from L1; accepts gossip | Refuse to serve peers; run a divergent fork choice; cannot forge anything | node (no protocol role); some become **attesters** |
| L1 block builder / validator | Includes L1 transactions | Order or censor `propose`/`prove` transactions; reorg L1 (bounded); under ePBS reveal an invalid payload after being paid | L1 (outside protocol) |
| Bridge relayer | Calls `processMessage` | Withhold service only; permissionless so no lock-in | relayer (unchanged) |
| Raiko host / proof system authors | Off-chain proving; guest programs | A guest bug = false proofs; a TEE compromise = forged SGX proofs (happened in June 2026) | proof-system supplier (code, upgraded by DAO) |
| DAO controller | Upgrades proxies | Malicious upgrade of any contract (outside R1's scope, but bounded by timelocks in practice) | DAO: **upgrades only** |
| `admin.taiko.eth` multisig | Ejecters, prover manager, SGX registrar, pauser, quota owner | Freeze or rotate the roster; pause bridging; register rogue SGX instances (with owner) | **removed from operation** |
| Etna-only: attester | Countersigns received blocks and timeouts | Collude with a sequencer to certify withheld blocks; refuse to attest (liveness) | attester (bonded standby sequencers) |
| Etna-only: challenger | Submits slashing evidence | False accusations (must be impossible or costly) | challenger (anyone) |

---

## 3. Trust assumptions, today and in Etna

| # | Assumption | Today | Etna |
|---|---|---|---|
| T1 | L1 (Ethereum) is live, censorship-resistant on a timescale of minutes, and reorgs are shallow | assumed | assumed; all windows in seconds or L1 block numbers, must survive 12/6/4/2-s slots (R5) |
| T2 | EIP-4844 blobs referenced by a landed transaction are available for the retention window (≈ 18 days) | assumed (`LibBlobs.sol:221-227`) | assumed; batches must be derived within the window |
| T3 | The accepted ZK proof systems are sound for the trusted program ids | assumed; TEE-only finalization was **not** sound (June 2026, `MainnetVerifier.sol:8-14`) | assumed for ZK only; TEE never sufficient for finality (assumption A3 in README) |
| T4 | The DAO acts honestly on upgrades | assumed | assumed; the DAO must not be needed for liveness (R1) |
| T5 | Whitelisted operators are honest and live | **relied upon** (no bond, no fallback) | **removed**; replaced by bonds, rotation, attestation, slashing |
| T6 | Whitelisted provers are honest and live | **relied upon** | **removed**; permissionless proving with rewards and a landing deadline |
| T7 | The admin multisig rotates SGX instances, ejecters, quotas in time | relied upon for proving liveness | **removed** from any liveness path |
| T8 | L2 nodes' L1 views agree closely enough (same operator, same roster) | assumed and violated near epoch boundaries and reorgs (`00-current-protocol-summary.md` §9.2 V2) | must be made objective: assignment computed from L1 state older than a reorg-safety window |
| T9 | Gossip reaches honest nodes within a bounded delay | assumed implicitly | assumed, with a stated bound δ; attestation quorum is the objective proxy |
| T10 | The golden-touch key is public and the node enforces "anchor first, 1,000,000 gas" | assumed (node-enforced, `Derivation.md:342-345`) | assumed; anchor correctness additionally ZK-proven |
| T11 | A minority of bonded participants is malicious | not applicable (no bonds) | assumed, in one form (round 4, R4-C1; stated identically on the arguments and certificate pages): fewer than one third of the seats are malicious; for liveness, fewer than m − Q(m) + 1 abstainers in a committee and its redraws; for safety, fewer than Q colluders |
| T12 | Frame Transactions (EIP-8141) ship on L1 as specified | not applicable | assumed for zero-cost races only; every other mechanism works without them (`03-frame-transactions-research.md` §8) |
| T13 | L2 nodes have loosely synchronized clocks (skew ≪ 1 s block time) | assumed silently; all slot gates use the host wall clock relative to beacon genesis (`00` §9.1) | assumed explicitly with a stated bound; every consensus decision (rights, deadlines, seeds) is a function of L1 blocks or L1 timestamps, and the wall clock is used only for local pacing and local timeouts that are later made objective by attestations |

---

## 4. Security properties

Etna must provide, and the design must argue:

- **P1 Safety (state).** No state root is finalized on L1 unless a valid ZK proof of the corresponding execution over L1-available data was verified. Bridges inherit this.
- **P2 Safety (preconfs).** A preconfirmed block that a node has treated as confirmed is only reorged if (a) the L2 preconf rules were violated by a bonded party who is then slashable, or (b) L1 itself reorged. The probability of (a) without slashing must be bounded by the attester-collusion assumption T11.
- **P3 Liveness.** If at least one honest, funded participant exists in each role and L1 is live, the chain keeps producing 1-s blocks and landing proven batches on L1 without any DAO or admin action.
- **P4 Censorship resistance.** A transaction posted through forced inclusion is included within a bounded time regardless of sequencer behaviour, or every sequencer who could have included it is slashed and a permissionless path includes it.
- **P5 Permissionlessness.** Every role is enterable and exitable by any address through objective on-chain conditions (R1).
- **P6 Accountability.** Every slashing condition is objectively verifiable on L1 by anyone from submitted evidence, with a stated evidence format, submitter, payout, and deterrent against false accusations (R6).
- **P7 Local decidability of preconfs.** Every node decides, immediately and locally, whether each preconfirmed block is valid according to rules that are identical across honest nodes (the brief's Section 2.3 property).
- **P8 Anti-monopoly.** No single party can hold sequencing rights for more than a bounded share of time without paying a super-linear cost (R6).

---

## 5. Threat catalogue

Severity is the impact if the threat is realized against Etna without a mitigation (Critical = loss of A1-A3 or permanent halt; High = prolonged halt, bounded theft, or unpunishable preconf reorg; Medium = degraded service or bounded griefing; Low = cost without safety or liveness effect).

| ID | Threat | Today | Etna must | Sev. |
|---|---|---|---|---|
| TH1 | **Forged or unsound proofs finalize a false state root** (A1-A3). | Happened with TEE-only composition (June 2026). Now `ZkRequiredVerifier` requires ≥ 1 ZK proof; ZK image ids are DAO-rotated. | Require ZK for finality; never accept TEE-only; state the k-of-n rule across independent ZK systems; treat verifier-set changes as DAO upgrades (allowed) but never as operational allowlists. Keep a bounded window in which a second proof system can veto? (open: decide in design) | Critical |
| TH2 | **Prover withholding / prover cartel** halts finalization and bridging. | No fallback: `permissionlessProvingDelay` is dead; whitelist has no time-based bypass; ring buffer fills in ≈ 3 days. | Permissionless proving with a per-batch reward; a landing deadline after which the sequencer is slashed and the batch is abandoned; multiple ZK back-ends. | High |
| TH3 | **Sequencer offline for its window** halts block production. | An offline epoch operator blocks the whole 384-s epoch; no fallback, no penalty. | Timeout-based takeover by a standby with an objective certificate; liveness slash of the absent sequencer. | High |
| TH4 | **Preconf equivocation** (two signed blocks at one height; or gossiped block ≠ proposed block). | Undetected; both clients accept up to 10 hashes per height; last valid wins; nothing recorded. | Equivocation is a slashable, objectively provable offence (two signatures); gossiped ≠ landed is made impossible by requiring the landing to carry the sealed, attested block set. | High |
| TH5 | **Withholding** (§6). | Fully possible; unpunished; enables TH4-like reorgs at handoff. | See §6. | High |
| TH6 | **MEV against users on stale state** (a sequencer sees private blocks others do not). | Possible; inherent to a single sequencer; amplified by withholding. | Reduce the window in which private state exists: attestation makes unpublished blocks worthless within one attestation round. Ordinary sequencer MEV is out of scope (see §8). | Medium |
| TH7 | **Forced-inclusion starvation** (sequencers never land, queue stuffing, blob expiry). | Due FIs must be consumed by the next `propose`, but only if some proposal lands; `permissionlessInclusionMultiplier` unenforced; blobs expired once and the queue was voided by admin. | Landing deadline plus a permissionless "forced batch" path once FIs age past a bound; per-second FI throughput floor; the design must show FIs cannot be used to burn a lander's slot (see `03` §4 claim 36). | High |
| TH8 | **Bond griefing** (make an honest party slashable, drain bonds through false accusations, dust deposits). | Bonds are zero; `depositTo` cannot re-activate a withdrawing account; settlement is best-effort. | Every slashing condition must be false-accusation-proof (evidence is a signature pair or an on-chain fact) and the accused must have had a way to avoid it. | High |
| TH9 | **Sequencing-right monopolization / Sybil** (one entity holds most windows; cartel excludes others). | Not applicable (roster is admin-curated). | Per-address caps, bond-per-seat Sybil cost, rotation with cooldown, randomness that cannot be ground cheaply; state the cost of holding X % of windows. | High |
| TH10 | **Role squatting** (register, never serve; occupy standby slots to degrade takeover). | Not applicable. | Missed-duty slashing and eligibility decay; registration cost; takeover order skips unresponsive standbys with objective certificates. | Medium |
| TH11 | **Landing-race waste** (two landers race; loser pays gas plus blob fees; a griefer burns the shared nonce or the L1 slot). | Loser reverts and pays; one proposal per L1 block. | Use the two-shape frame-transaction gate (`03` §8) so losers pay nothing; keep a per-block spam bound; ensure no third party can make the winner revert after payment approval (FI-by-due-time, pull fees). Degrades to today's revert model without EIP-8141. | Medium |
| TH12 | **L1 reorg** un-mines a landed batch or changes the assignment inputs. | Clients rewind `head L1 origin`; Go re-checks every 10 s; assignment reads at "latest" so nodes can disagree. | Assignment inputs taken from L1 state at least REORG_SAFETY seconds old; landed batches carry expected-parent binding; nodes treat L1 finality as the only irrevocable point. | Medium |
| TH13 | **L1 congestion / gas** (blob fees spike; landing tx exceeds block share at short slots). | Proposer just retries with fee bumps. | Landing deadline long enough for a fee spike; batch size per second, not per block; verifier gas budget documented against the EIP-7825 cap and a 2-s-slot block (`02` §5). | Medium |
| TH14 | **P2P DoS** (gossip flooding, request storms, eclipse of a node). | Per-peer token buckets, per-height caps, 768-entry caches; no peer scoring visible; anonymous gossipsub authenticity. | Signed messages only from bonded keys; rate limits per bonded identity; eclipse tolerance via the L1 landing path as the fallback source of truth. | Medium |
| TH15 | **Slot-time change** breaks timing (6/4/2-s slots). | Many constants hard-code 12 s (`00` §11). | No slot or epoch constants anywhere; seconds and L1 block numbers only; windows re-validated against the `02` §5 table. | High (for R5) |
| TH16 | **Frame-transaction spec drift** (expiry verifier address, calldata length, opcode numbers, keyed nonces). | Not applicable. | Gate contracts versioned per fork, fail closed, with a direct path behind a governance switch; nothing but zero-cost races depends on EIP-8141. | Medium |
| TH17 | **False or stale L1 checkpoint on L2** (anchor carries a wrong L1 hash/state root; L1→L2 bridge messages proven against it). | Anchor does not verify; correctness rests on derivation and, eventually, the L1 proof; a wrong anchor would fail the proof and be reorged. | The ZK proof must bind the anchored L1 checkpoints to true L1 block hashes (public input includes the L1 hashes checked on L1 via `blockhash`/EIP-2935 or a recorded checkpoint list). | Critical |
| TH18 | **Signature-verification hazard from EIP-8151** (ecrecover returns zero for accounts with code). | Not applicable. | Slashing and attestation keys must be plain EOAs or use EIP-2537 BLS; registration rejects addresses with code. | Low |
| TH19 | **DAO or admin capture / inaction.** | Inaction halts rotations (TH2/TH3 paths); capture can upgrade anything. | Inaction has no liveness effect (R1). Capture is out of scope beyond R1's "upgradeability only" (timelocks and vetoes are governance design, not protocol design). | High (inaction) |
| TH20 | **Proof-system rotation kills in-flight proofs** (image-id rotation invalidates proofs being generated). | Happens on every raiko release. | Accept both old and new ids during an overlap window expressed in seconds; rotation is a DAO upgrade, but it must not halt landing. | Medium |
| TH21 | **Bridge quota / pause used as a lever** (pausing SignalService halts all bridging). | Owner or pauser can pause; no liveness effect on L2 itself. | Unchanged (R2 freezes these); noted as an accepted governance-level dependency of bridging, not of the rollup. | Low |
| TH22 | **Data-availability of the preconf chain before landing** (a node that missed gossip cannot catch up; no range request). | Per-hash requests only; L1-derived blocks cannot be served. | Attestations imply availability from a quorum; add a range-sync primitive; landing within the deadline is the backstop. | Medium |
| TH23 | **P2P request amplification** (unauthenticated `requestPreconfBlocks` / end-of-sequencing request topics make every operator node do lookups and publish responses). | Present: requests carry no signature (`// TODO: add signer`), only per-peer and per-hash rate limits (`00` §9.1). | Authenticate range-sync and parent requests (signed by a registered key or paid), rate-limit by identity, and never let a request trigger unbounded work; range-sync responses must be servable from any node, not only operators. | Medium |
| TH24 | **Clock skew or clock manipulation changes who may build** (all slot and epoch gates evaluated from the host wall clock). | Present in the Go driver; Rust ignores epochs entirely. | No consensus rule may depend on a node's wall clock (T13); sequencing rights, deadlines and seeds are functions of L1 block identity; 1-s pacing is local and only its *output* (a signed block with an L1-bounded timestamp) is judged. | Medium |
| TH25 | **Guest / contract / client constant drift** (chain ids, fork times, predeploy addresses, storage slots and anchor gas limit are compiled into the ZK guest; the remote Groth16/PLONK verifier addresses are immutable and a codeless address would accept everything). | Present (`00` §4.4, §4.5); every raiko release rotates ids by DAO proposal; fork times live only in the two execution clients. | Treat every compiled-in constant as a versioned protocol parameter published on L1 and read by guest, clients and contracts from one source; verifier-address changes are DAO upgrades with an overlap window (TH20); the design must state which constants the public input commits to. | High |

---

## 6. The withholding attack, in depth

### 6.1 Definition

A party holding an active role builds blocks (or proofs, or seals) and does not publish them to the P2P network, then uses private knowledge of the withheld data to harm others: invalidate a competitor's blocks or proofs, extract MEV against users who transact on stale state, grief provers, or force a reorg of blocks other nodes already treated as confirmed.

### 6.2 Variants

| Variant | Attacker | What is withheld | Harm | Today |
|---|---|---|---|---|
| W1 Handoff ambush | outgoing sequencer A | its last m blocks | the incoming sequencer B builds on a stale head; A lands the withheld blocks; B's blocks and every preconf B issued are reorged; B's users' transactions re-execute on a different state | fully possible, unpunished (`00` §10 (d)) |
| W2 Private MEV | current sequencer | all blocks for a while | users transact against stale state; the sequencer arbitrages | possible; not distinguishable from "no blocks" |
| W3 Prover grief | sequencer | the batch content the provers need | provers cannot prove; the sequencer can prove itself and land late, or never | possible; provers only see L1 |
| W4 Selective withholding | sequencer | one block in a chain | children arrive but cannot be executed; caches fill (768); nodes stall | possible; parent requests answered only by the withholder |
| W5 Seal / attestation withholding (Etna-only) | sequencer or attester | the seal or the certificate needed for the next block | liveness stall; if the certificate is required for landing, the batch cannot land | new to Etna; must be designed for |
| W6 Proof withholding | prover | the proof | finalization and bridging stall; ring buffer fills | possible; no fallback |
| W7 Blob withholding | proposer | blob data | impossible after landing (same-transaction blob hashes) | impossible |

### 6.3 The fundamental limitation

Non-receipt of a message is **not provable on-chain**. No contract can distinguish "A never sent block k" from "B claims A never sent block k". Therefore any defence must work through one or more of:

1. **Timeouts on L1-observable events.** Objective: "no batch for window T was landed by deadline D" is an L1 fact. Cost: it only detects withholding that also fails to land, so an attacker who lands late but in time is not caught by this alone. False positives: an honest sequencer whose provers all failed. False negatives: withholding within the deadline.
2. **Attestations by bonded third parties.** A block is "public" if a quorum of bonded attesters signed that they received and validated it. Objective facts derivable from attestations: equivocation (two attestations at one height), attesting a block whose parent lacks a certificate, and "a block without a certificate was landed" (if landing requires the certificate). False positives: a partitioned honest sequencer fails to collect a quorum. False negatives: a sequencer colluding with ≥ quorum attesters certifies a block only they hold. The collusion cost is quorum × bond, which is the parameter the design must table.
3. **Bonded availability claims.** The sequencer posts a bond against a claim "block k was published"; a challenger can demand the data on L1 (a data-request game). Cost: an L1 round-trip per challenge and a way to punish frivolous requests; incompatible with 1-s cadence except as a rare escalation.
4. **Making withheld data worthless.** If a block cannot be extended (V3 requires a parent certificate) and cannot be landed (landing requires the certificate), withholding has no payoff except a liveness failure that is itself slashable. This turns W1-W4 into TH3 (absence), which is objective.

### 6.4 What Etna must specify (checklist for the design and the red team)

- The exact predicate under which an honest node stops extending the current sequencer's chain and starts the takeover, and why two honest nodes reach the same decision from the same messages (P7).
- The certificate format carried in each block (or seal) and its verification cost off-chain (per second) and on-chain (per landing).
- The quorum size, the committee selection rule, and the collusion cost table (false-negative bound).
- The partition / latency bound δ under which an honest sequencer always gathers a quorum (false-positive bound), and what happens if it does not (missed window, slashed or not?).
- What a user is told: "attested" versus "sequencer-signed only" versus "landed" versus "finalized", with the guarantee at each level.
- The proof that W1 is impossible without slashing: the incoming sequencer's first block must reference the outgoing sequencer's last *certified* block; any later landing by the outgoing sequencer that extends beyond that block is either uncertifiable or slashable.
- The behaviour of provers (W3): whether provers require certificates before proving and what they are paid if a batch is abandoned.
- The interaction with forced inclusion (W5): a withheld seal cannot postpone a due forced inclusion beyond its deadline.

---

## 7. Requirements-to-threats matrix

| Req. | Threats it must defeat | Design sections that must carry the argument |
|---|---|---|
| R1 permissionless | TH2, TH3, TH19, TH9 (no admin substitutes) | role registry, sequencing rights, prover entry, upgrade path |
| R2 reuse shared contracts | TH17, TH21 | bridge integration, upgrade path |
| R3 richer roles | TH3, TH5, TH22 | attester role, challenger role, failure analysis per role |
| R4 1-s blocks | TH5, TH6, TH22, TH23 | preconf validity rules, certificate latency budget |
| R5 no lookahead / no slot coupling | TH12, TH15, TH24 | sequencing rights (randomness, snapshots), parameter table units |
| R6 slash and anti-monopoly | TH4, TH8, TH9, TH10, TH18 | slashing catalogue, evidence formats, anti-monopoly parameters |
| R7 propose-with-proof | TH1, TH2, TH7, TH11, TH13, TH16, TH20, TH25 | landing frame, deadline and replacement, forced inclusion, frame-tx gate and fallback |

---

## 8. Out of scope

- Ordinary sequencer MEV within a public, attested block stream (fair ordering is a separate research area; Etna only removes the *private-state* amplification).
- Malicious DAO upgrades (R1 leaves upgradeability with the DAO; timelocks and vetoes are governance design).
- L1 consensus failures (deep reorgs, finality failure) beyond the stated reorg-safety window.
- Cryptographic breaks of secp256k1, BLS12-381, KZG, or the ZK proof systems' underlying assumptions; proof-system implementation bugs are in scope only through the k-of-n composition rule (TH1).
- Bridge application-level bugs unrelated to checkpoints (R2 freezes the Bridge and Vault logic).

Open items carried from Phase 1 (unanswered gap fills, budget-limited; each is a fact-finding task, not a design decision):

- G8: proposer economics today (what a whitelisted operator earns per epoch from L2 fees and MEV; needed to size the sequencer bond).
- G9: the blob-fetch paths in both drivers (beacon node by slot, blob server fallback) and how they behave when a blob is past retention.
- G10: the L2 fee flow in detail (coinbase share, Anchor share, priority fees) and the Anchor's accumulated balance on mainnet.
- G11: the Bridge quota state on mainnet (which tokens are throttled and by how much).
- G12: the raiko SGX lane's remaining role after `ZkRequiredVerifier`, and whether any mainnet proof still uses it.
