# URC Production‑Readiness Review (for Taiko permissionless preconfirmations)

**Subject:** Universal Registry Contract — [`eth-fabric/urc`](https://github.com/eth-fabric/urc) @ `132bc79` (2025‑07‑07, `main` HEAD)
**Reviewed for:** using the URC as the operator‑registry + slashing backbone for Taiko's *permissionless* preconfirmations.
**Review date:** 2026‑08.
**Assumed sequencing (per the brief):** ePBS (EIP‑7732, Glamsterdam ~Q4 2026) lands, then FOCIL (EIP‑7805, Hegotá ~2027); shorter slots (EIP‑7782) deferred.

---

## 0. Bottom line up front

The URC is a **well‑conceived but not‑yet‑production‑ready** contract. Its architecture (immutable, ETH‑only, governance‑free, arbitrary‑slasher) is sound and it is the right *standard* to align with. But at its current `main` HEAD it is **not safe to deploy as an immutable custodian of real collateral**, for three independent reasons:

1. **Process/state readiness is red.** `main` has been frozen for ~13 months. The contract's own README still says *"not audited and is not ready for production use,"* the roadmap's "Audit 3" is unchecked, and the two audits that did happen (Zellic, Hashlock) both **pre‑date** the current HEAD (the Solady‑library swap in `#66` landed after them, unreviewed) and **neither report is public**. Worse, the BLS‑signing correctness fix lives only on an **unmerged, unaudited `signing-domain` branch** — so `eth-fabric/fabric` builds against `signing-domain` while Taiko's `package.json` pins `urc#main`. There is **no canonical deployment on any network and zero production users**; every live preconf system (ETHGas, Primev, Puffer, Taiko mainnet itself) runs its own registry or a whitelist.

2. **There are real, exploitable contract bugs at HEAD**, including two High‑severity issues in the slashing logic (a missing replay‑guard on the opt‑in slashing path, and a self‑triggerable "escape the slash window" path) and several Medium issues (delegation not binding the slasher, cross‑deployment signature replay enabling *wrongful* equivocation slashing, and getters that misreport an operator's slashable status). These are fixable, but the fixes touch the signed‑message schema and the slashing state machine — i.e., they must be made and audited **before** an immutable deployment, because they cannot be patched afterward.

3. **The immutability + ePBS timing is a trap.** The URC *core* (registration, collateral, opt‑in, accounting) is payload‑flow‑agnostic and survives ePBS. But ePBS (~the same Q4 2026 window as a Taiko launch) reshapes the *commitment supply chain*: the proposer commits to a builder's bid without seeing the payload, so execution‑preconf enforcement moves onto the proposer→builder relationship. The URC's `Delegation`/`Commitment` schema — which is frozen forever once deployed — has **no notion of a builder or of enforceable constraints**, and every slasher that proves faults from block structure/timing must be rebuilt for the new block anatomy. Deploying an immutable URC just before ePBS risks locking in a schema that ePBS makes awkward.

**Recommendation:** **Do not** ship permissionless preconfs on the URC's current `main` HEAD. Keep the permissioned `PreconfWhitelist` (live on Taiko Alethia since Aug 2025) as the interim path. Treat the URC as adoptable **only after**: (a) `signing-domain` is merged to `main`, (b) a fresh audit ("Audit 3") covers the exact to‑be‑deployed bytecode and prior reports are published, (c) the contract bugs in §2 are fixed, and (d) an explicit ePBS‑compatibility analysis of the `Delegation`/`Commitment` schema is completed. Pin Taiko to an audited tag/commit, **never** to a moving branch. The detailed, itemized change list is in §5.

---

## 1. What was reviewed and how

- **First‑hand line‑by‑line read** of `src/Registry.sol` (789 LoC), `src/IRegistry.sol`, `src/ISlasher.sol`, `src/lib/BLSUtils.sol`, `src/lib/MerkleTree.sol`, `src/lib/BLS.sol`, both `example/*` slashers, `test/*`, gas snapshots, and the three load‑bearing commits (Hashlock fixes `8bb7136`, opt‑out‑window `5f18225`, timestamp‑windows `638dbcf`).
- **Two independent audit‑grade passes** (Registry/slashing; crypto libs).
- **Taiko integration mapping**: the (now‑parked) `permissionless-preconf` branch, its `LookaheadStore`/`UnifiedSlasher`/`PreconfSlasherL1/L2`/`LookaheadSlasher`/`Blacklist`, and the design doc `packages/protocol/docs/preconfirmation_lookahead.md`.
- **Ecosystem/process research**: maintenance status, audit provenance, deployments, adopters, and published ePBS/FOCIL analyses.

Severity uses the standard impact×likelihood convention. Where a finding is mitigated by *how Taiko specifically uses the URC*, that is called out — the URC is a general‑purpose contract and some sharp edges are only reachable through code paths Taiko may not use.

---

## 2. Security findings in the URC core (contract code)

| # | Severity | Finding | Location |
|---|----------|---------|----------|
| H‑1 | **High** | Operator can self‑start the global `slashWindow` and become permanently un‑slashable while reclaiming ~all collateral | `Registry.sol:205, 348‑351, 518‑546, 589‑592` |
| H‑2 | **High** | Opt‑in `slashCommitment` overload has **no replay protection**; one commitment can be replayed to burn ~all of an operator's collateral | `Registry.sol:322‑366` |
| M‑1 | **Medium** | BLS `Delegation` does not bind the slasher → a compromised/malicious committer key can burn full collateral via an arbitrary slasher | `Registry.sol:286‑320`, `ISlasher.sol:8‑19` |
| M‑2 | **Medium** | Signed registration/delegation messages omit chain‑id + contract address → cross‑deployment replay → **wrongful** equivocation slashing of honest operators | `Registry.sol:20‑21, 246, 749`; `BLSUtils.sol:142‑150` |
| M‑3 | **Medium** | Per‑slasher getters (`isOptedIntoSlasher`, `isSlashed(root,slasher)`) ignore global `slashedAt` → integrators are told an operator is bonded when it is hours from immunity | `Registry.sol:584‑592, 610‑641` |
| L‑1 | Low | Immutable constructor performs **zero `Config` validation**; a misconfiguration permanently bricks slashing/withdrawals | `Registry.sol:26‑28` |
| L‑2 | Low | `verify()` accepts the identity/infinity pubkey + infinity signature as valid for any message | `BLSUtils.sol:171‑190` |
| L‑3 | Low | `getHistoricalCollateral` uses strict‑`<` semantics and **reverts (underflow panic)** when queried exactly at the first record's timestamp | `Registry.sol:610‑641` |
| L‑4 | Low | `slashEquivocation` lacks the below‑minimum guard that `slashRegistration` has → an already‑slashed operator becomes un‑equivocation‑slashable (subtraction underflow reverts) | `Registry.sol:430` vs `:237` |
| D‑1 | Design | Production BLS "hash‑to‑curve" is a **non‑standard `encode_to_curve`** (keccak256 → one `Fp2` coeff → single map), not RFC 9380; incompatible with standard Ethereum consensus BLS tooling and outside the BLS security proof | `BLSUtils.sol:142‑150` |
| I‑1 | Info | No reentrancy guard anywhere; safe today only by CEI + per‑operal accounting — fragile | `Registry.sol:314, 360, 505, 535` |
| I‑2 | Info | Equivocation "same‑delegation" check ignores `metadata`; the same BLS key can be registered under multiple roots | `Registry.sol:383‑390, 54` |
| I‑3 | Info | Domain‑separator constants are ASCII **string literals**, not the 4‑byte values the comments imply | `Registry.sol:20‑21` |

### H‑1 — Self‑triggerable slash‑window escape

`slashedAt` is a single **per‑operator global** timestamp, set on the *first* slash of any kind. All commitment slashing is then gated by `isSlashableCommitment` (`Registry.sol:205`): after `slashedAt + slashWindow` every slashing path reverts `SlashWindowExpired`, and the operator withdraws all remaining collateral via `claimSlashedCollateral` (`:530`) and is marked `deleted`. Because an operator can *self‑slash for 1 wei* (deploy a trivial `ISlasher`, opt in, sign a commitment with a committer key they control), they can **start this global countdown at a time of their choosing** and, after one `slashWindow`, become permanently immune with ~all collateral intact.

The escape is only fully effective when a real violation's evidence matures *after* the window closes — which is exactly the case when the slasher's own challenge latency approaches or exceeds `slashWindow`. Note the example slashers ship with `CHALLENGE_WINDOW = 7200s` and require finalization (`JUSTIFICATION_DELAY = 32` slots), while the sample config sets `slashWindow = 7200s` — i.e., the default parameters make the escape viable. It is made stealthy by **M‑3**: `isOptedIntoSlasher(root, L)` keeps returning `true` for a legitimate slasher `L` even after the operator has self‑slashed and is counting down to immunity.
**Fix:** make the slash window **per‑slasher** (track `slashedAt` inside `SlasherCommitment`) so one slasher's clock cannot release the operator from another's; reconcile the getters (M‑3); constrain `Config` so `slashWindow` must exceed realistic evidence‑maturation latency (L‑1).

### H‑2 — Opt‑in `slashCommitment` replay (missing `slashedBefore` guard)

The delegation‑based `slashCommitment` (`:286‑320`) and `slashRegistration` (`:213‑283`) both compute a `slashingDigest` — folding in `keccak256(evidence)` — and record it in `slashedBefore` to prevent replays (this was the Hashlock H‑01/H‑02 fix). **The opt‑in `slashCommitment` overload (`:322‑366`) does none of this.** It sets `slasherCommitment.slashed = true` (`:354`) but never reads that flag as an entry guard, and it computes no digest. So the **same `(commitment, evidence)` pair can be submitted repeatedly** within the slash window; each call re‑invokes `ISlasher(slasher).slash(...)` and burns whatever it returns. Against a *stateless* slasher that returns a fixed amount for valid evidence — exactly the pattern of `example/StateLockSlasher.sol` and the test `DummySlasher` — an attacker replays one legitimate commitment `⌊collateral / SLASH_AMOUNT⌋` times and burns the operator's **entire** stake for a single offense. The only stop is `_slashCommitment`'s `slashAmountWei > collateralWei` revert (`:681`), i.e. at ~0.

**This is the most important contract bug: it is unambiguous, trivially exploitable once evidence is public (pure griefing, funds burned to `address(0)`), and asymmetric with the two already‑protected paths.** It is also the path Taiko's design uses (operators opt into `preconfSlasher`/`lookaheadSlasher`).
**Fix (trivial):** mirror the delegation path — `slashingDigest = keccak256(abi.encode(registrationRoot, commitment, keccak256(evidence)))`, revert if `slashedBefore[digest]`, set before the external call.

### M‑1 — Delegation does not bind the slasher

The operator's BLS‑signed `Delegation` commits to `{proposer, delegate, committer, slot, metadata}` — **not to any slasher**. In the delegation `slashCommitment`, the slasher is read from the *commitment*, which is signed only by the committer's ECDSA hot key (`:305, :314`). So anyone holding a gossiped `SignedDelegation` plus the committer key can name **any** slasher — including an attacker‑deployed one that returns full `collateralWei` — and burn the operator's whole stake, with no on‑chain revocation short of unregistering. The blast radius of a gateway/committer key compromise is thus unbounded.
Taiko partially sidesteps this by using the **opt‑in** slashing path (slasher constrained to one the operator opted into on‑chain), but the delegation path remains in the contract and is exposed to any operator who uses it.
**Fix:** add an allowed‑slasher (or slasher‑set commitment) field to the BLS‑signed `Delegation` and enforce `commitment.slasher ∈` that set.

### M‑2 — Cross‑deployment replay → wrongful equivocation slashing

Signed messages are `keccak256(DST ‖ abi.encode(owner|delegation))` with a **fixed constant** DST containing no `block.chainid`, no `address(this)`, and no nonce. A `SignedDelegation` valid on one URC deployment is valid **byte‑for‑byte on every deployment** where the same BLS key is registered, and beacon slot numbers are global. Two *honest* delegations an operator made on two deployments (e.g., an L1 URC and Taiko's own URC instance, or testnet↔mainnet) for the same slot can be combined and submitted as an `slashEquivocation` on whichever deployment the operator is registered — slashing an honest operator. Registration signatures are equally portable.
**Fix:** bind `block.chainid` + `address(this)` (EIP‑712‑style domain) into the DST at construction. *Note:* Taiko already recognized this class of issue and added EIP‑712 domain separation for its **own** lookahead commitments (taiko‑mono `#21346`); the same discipline needs to exist inside the URC for registration/delegation.

### M‑3, L‑1..L‑4, D‑1, I‑1..I‑3
- **M‑3:** `isOptedIntoSlasher`/`isSlashed(root,slasher)` consult only the per‑slasher `SlasherCommitment` and ignore global `slashedAt`; a consumer using the documented getters can be shown a "bonded, opted‑in" operator that is in fact slashed and counting down to withdrawal. Make them reflect `slashedAt`.
- **L‑1:** constructor stores `Config` with no checks; `slashWindow == 0`, `minCollateralWei == 0`, or `fraudProofWindow == 0` each permanently break security with no upgrade path. Validate in the constructor.
- **L‑2:** `verify(pubkey=O, sig=O, any msg)` returns `true` (identity element passes the pairing). A registration with an infinity key is *not* fraud‑slashable. Reject identity points; ideally validate the pubkey once at `register()`. (Broader point: the URC never checks a registered key is a real, staked beacon‑chain validator — preconf economic security = URC collateral only, linked to consensus identity solely by the off‑chain lookahead + slashing.)
- **L‑3:** `getHistoricalCollateral(root, t)` with `t == records[0].timestamp` passes the guard, then computes `high = 0 - 1` → arithmetic‑underflow panic; generally it returns the value *strictly before* `t`. Taiko's `LookaheadStore` avoids this only because it separately requires `registeredAt < referenceTimestamp`. Fix the boundary semantics (use `<=`, guard the underflow).
- **L‑4:** `slashEquivocation` does `collateralWei -= minCollateralWei` (`:430`) with none of the `CollateralBelowMinimum` guard that `slashRegistration` has (`:237`); an operator already slashed below `min` reverts on equivocation slashing. Add the guard / clamp.
- **D‑1:** the live signing scheme is a bespoke `encode_to_curve` over keccak256, not RFC 9380 `hash_to_curve` (no `expand_message_xmd`, SHA‑256, or two‑field‑element mapping; only `c1` populated). No concrete forgery is demonstrable, but it is outside the standard BLS UF‑CMA proof and **incompatible with standard Ethereum validator BLS tooling**. The RFC‑9380 implementation exists in the (unused) `src/lib/BLS.sol` and the fix exists on the unmerged `signing-domain` branch (`#68`). Merge it and stop describing the scheme as standard.
- **I‑1:** no `nonReentrant` anywhere; the arbitrary `slasher.slash()` callback and all ETH‑out paths forward full gas. Currently safe (claims set `deleted=true` before transfer; `_slashCommitment` re‑reads collateral and caps after the call), but add explicit guards — this is defense that should not rely on reviewers re‑deriving CEI each change.
- **I‑2:** the equivocation sameness check ignores `metadata` ("reserved for future use") — if `metadata` ever gains meaning, conflicting commitments could evade equivocation liability. Off‑chain infra must key operators by `registrationRoot`, not BLS key (the same key can appear under multiple roots).
- **I‑3:** `REGISTRATION_DOMAIN_SEPARATOR = "0x00555243"` is the 10 ASCII bytes of that text, not the 4‑byte tag the comment claims. Harmless (sign/verify agree) but shows the DST was not deliberately constructed; fold into the M‑2 chain‑bound DST.

### Positively verified (not findings)
EIP‑2537 precompile addresses match the final Pectra spec; MSM/pairing precompiles perform subgroup checks; Merkle usage (Solady, 416‑byte structured pre‑image recomputed from stored owner) is not second‑preimage‑exploitable; G1 compression is off‑chain only; registration front‑running is neutralized by owner‑binding; `addCollateral` overflow is guarded; the Hashlock fixes are correctly applied **except** that the replay guard was never extended to the opt‑in path (→ H‑2). Gas: the hot path (`checkProposer` inside `Inbox.propose`) does no BLS work; BLS verify (~135k gas) is confined to challenger‑paid slashing paths.

---

## 3. Process, maintenance & ecosystem readiness

| Dimension | Status | Evidence |
|---|---|---|
| Code freshness | ❌ `main` frozen ~13 months at `132bc79` (2025‑07‑07) | `git ls-remote` HEAD; commits page |
| Audit coverage of HEAD | ❌ Zellic (Audit 1) + Hashlock (Audit 2) both pre‑date HEAD; the Solady swap (`#66`) is unreviewed; "Audit 3" unchecked | `docs/overview.md`; PRs `#53`, `#65`, `#66` |
| Audit reports public | ❌ Neither Zellic nor Hashlock report is published | Hashlock public repo has no URC entry; Zellic shared only a Drive draft |
| Self‑description | ❌ README still: *"not audited and is not ready for production use"* | `README.md` |
| Signing‑scheme fix | ⚠️ Lives only on **unmerged, unaudited `signing-domain`** (`#68`); `eth-fabric/fabric` uses it, Taiko pins `urc#main` | org repos; `package.json:63` |
| Canonical deployment | ❌ None found on mainnet / Holesky / Hoodi / Helder | deploy scripts take `$REGISTRY_ADDRESS`; Fabric docs list none |
| Production users | ❌ Zero — every live protocol uses its own registry/whitelist | SoK: Preconfirmations (arXiv 2510.02947); ETHGas/Primev/Puffer docs |
| Maintainer capacity | ⚠️ Effectively a single author (J. Vranek); Fabric org alive but slowing; Commit‑Boost URC module idle since Oct 2025 | git shortlog; org activity |

Implication: if Taiko ships permissionless preconfs on the URC, **Taiko would be its first and only production deployment**, on code the authors disclaim as unaudited, with the standard‑BLS fix stranded off‑`main`. This is a governance/liability posture that must be consciously accepted, not inherited by default. Because the contract is *immutable*, the usual "ship and patch" escape does not exist.

---

## 4. ePBS (EIP‑7732) and FOCIL (EIP‑7805) impact

**Split the system into three layers; they age very differently:**

1. **URC core (Registry, interfaces, collateral, opt‑in, accounting): fork‑agnostic.** It parses no consensus or execution structures. Registration, delegation (proposer‑BLS → committer), equivocation (two delegations, same slot), and collateral accounting all survive ePBS and FOCIL **unchanged**. The one caveat is schematic, not mechanical — see below.

2. **The commitment *semantics*: reshaped by ePBS.** Under EIP‑7732 the `ExecutionPayload` becomes a builder's `SignedExecutionPayloadBid`; **builders become staked in‑protocol entities**, the proposer commits to a bid *without seeing the payload*, and a Payload‑Timeliness Committee attests to reveal. Nethermind's *Future‑Proofing Preconfirmations* is explicit: without **enforceable constraints on the winning builder** (via the Constraints API), the proposer *cannot* honor execution preconfs and the builder has no obligation to. So execution‑preconf enforcement must be re‑mapped onto proposer→builder. The URC's `Delegation`/`Commitment` structs have **no builder field and no constraints notion**, and this schema is **frozen forever at deployment**. This is the single most consequential forward‑compat decision: either (a) deploy now and accept that ePBS enforcement will be bolted on entirely in the slasher layer, or (b) extend the schema first. Fabric's own research has already begun pivoting the commitment substrate toward **BALs (EIP‑7928)**, which signals the maintainers expect this layer to move.

3. **The slashers: ePBS‑fragile and must be rebuilt.** Both URC *example* slashers and Taiko's `PreconfSlasherL1/L2` + `LookaheadSlasher` prove faults by decoding RLP execution headers (fixed field indices), `blockhash()` + MPT `txRoot` inclusion proofs, and EIP‑4788 beacon roots, with **hard‑coded** `SLOT_TIME = 12`, `JUSTIFICATION_DELAY = 32`, and per‑chain beacon genesis. Under ePBS the block anatomy, payload availability (withholdable, PTC‑attested), and proposer→payload mapping all change; every fault‑proof must be re‑derived and re‑validated against the Gloas fork‑choice on ePBS devnets — this is precisely the Q4 roadmap item. If EIP‑7782 (6s slots) later lands, the hard‑coded `SLOT_TIME`/lookback constants must become parameters.

**FOCIL (EIP‑7805):** net‑positive and largely compatible for a based rollup — mandatory inclusion lists compose with forced inclusion. The one spec obligation is Taiko‑side: a gateway's **ordering commitments must be defined to coexist with forced‑in IL transactions** (a gateway cannot promise to *exclude* an IL‑mandated tx). This is a `LookaheadStore`/gateway‑spec detail, not a URC‑contract change.

**Net for the URC contract itself:** ePBS/FOCIL require **no mechanical change to the Registry core**, but they do force a **decision about the `Delegation`/`Commitment` schema before an immutable deploy**, because that schema is the one ePBS‑relevant thing that can never be changed later.

---

## 5. Full, detailed change list

Grouped by owner. **Part A** = changes to the URC repo (`eth-fabric/urc`) itself; **Part B** = URC process/release gating; **Part C/D** = fork‑driven; **Part E** = Taiko‑side integration (`taiko-mono`, not the URC). Items are ordered by priority within each part. "Pre‑deploy" = must land before the immutable mainnet URC is deployed, since it cannot be changed after.

### Part A — URC contract/code changes (in `eth-fabric/urc`)

| ID | Pri | Change | Why (finding) | Notes |
|----|-----|--------|---------------|-------|
| A‑1 | **P0** | Add replay protection to the opt‑in `slashCommitment(bytes32, SignedCommitment, bytes)` overload: compute `slashingDigest = keccak256(abi.encode(registrationRoot, commitment, keccak256(evidence)))`, revert on `slashedBefore[digest]`, set before the external call. | H‑2 | Trivial, isolated; mirrors the two already‑protected paths. **Highest priority.** |
| A‑2 | **P0** | Redesign the slash‑window state machine so it is **per‑slasher**, not a single self‑triggerable global `slashedAt`. Track `slashedAt`/window inside `SlasherCommitment`; ensure a slash by slasher X cannot shorten the window for slasher Y or accelerate `claimSlashedCollateral`. | H‑1, M‑3 | Deepest change; touches `claimSlashedCollateral`, `isSlashableCommitment`, and the getters. Pre‑deploy (state‑machine, unpatchable). |
| A‑3 | **P0** | Add an allowed‑slasher binding to the **BLS‑signed** `Delegation` (a `slasher` field or a commitment to a slasher set) and enforce `commitment.slasher ∈` it in `slashCommitment`. | M‑1 | **Schema change → pre‑deploy.** Coordinate with the Constraints‑API/Commitments‑API spec. |
| A‑4 | **P0** | Bind `block.chainid` + `address(this)` into the registration and delegation signing domains (EIP‑712‑style domain fixed at construction); give delegations an explicit deployment/domain field rather than relying on `slot`. | M‑2, I‑3 | **Schema change → pre‑deploy.** Eliminates cross‑deployment replay & wrongful equivocation slashing. |
| A‑5 | **P0** | Adopt RFC 9380 `hash_to_curve` (SHA‑256 `expand_message_xmd`, two field elements, proper `DST_prime`) for production `verify` — i.e., merge the `signing-domain` work (`#68`) into `main`. Stop describing the scheme as standard if a bespoke one is kept. | D‑1 | **Pre‑deploy** and interop‑critical (consensus‑key tooling). Resolves the two‑codebase divergence. |
| A‑6 | P1 | Reject the identity/infinity element for both pubkey (G1) and signature (G2) in `verify`; validate the registered pubkey once in `register()`. | L‑2 | Cheap; closes the "un‑fraud‑slashable infinity key" hole. |
| A‑7 | P1 | Add constructor `Config` validation: non‑zero `minCollateralWei`, `fraudProofWindow`, `slashWindow`, `unregistrationDelay`, `optInDelay`, and enforce `slashWindow ≥` max realistic evidence‑maturation latency of intended slashers. | L‑1 | **Pre‑deploy** (bricking risk is permanent). |
| A‑8 | P1 | Make `isOptedIntoSlasher` and `isSlashed(root, slasher)` also reflect global `slashedAt`/`deleted`; document/repair `getHistoricalCollateral` boundary semantics (`<=`, guard the `high = mid‑1` underflow). | M‑3, L‑3 | Integrator‑facing correctness; pairs with A‑2. |
| A‑9 | P1 | Add the below‑minimum guard to `slashEquivocation` (match `slashRegistration`), or clamp the decrement. | L‑4 | Removes the "already‑slashed ⇒ un‑equivocation‑slashable" gap. |
| A‑10 | P2 | Add explicit `nonReentrant` guards to `slashCommitment` (both overloads), `slashRegistration`, `slashEquivocation`, and the claim functions. | I‑1 | Defense‑in‑depth; don't rely on hand‑verified CEI. |
| A‑11 | P2 | Resolve the open **delegation‑message encoding** spec (`urc#19`); include `metadata` in the equivocation sameness check (or forbid semantic `metadata`); document that a BLS key can map to multiple roots. | I‑2 | Also unblocks off‑chain tooling. |
| A‑12 | P2 | Add leaf/internal‑node domain separation to the Merkle construction (e.g. `0x00`/`0x01` prefix). | (defense‑in‑depth) | Not exploitable today; cheap hardening. |
| A‑13 | P2 | Fix domain‑separator constants to real bytes (`hex"…"`) as part of A‑4. | I‑3 | Cosmetic once A‑4 lands. |

### Part B — URC process / release gating (non‑code, but blocking)

- **B‑1 (P0):** Commission **"Audit 3"** against the *exact bytecode to be deployed* — i.e., after A‑1..A‑9 and the `signing-domain` merge — not against any historical state. **Publish** the Zellic and Hashlock reports so adopters can see the prior finding surface.
- **B‑2 (P0):** **Merge `signing-domain` → `main`** and eliminate the divergence between what `eth-fabric/fabric` builds and what Taiko pins. Cut a **tagged release**; Taiko must pin `package.json` to that **immutable tag/commit**, never `urc#main` (currently `packages/protocol/package.json:63` pins the moving branch).
- **B‑3 (P1):** Add the **negative and invariant tests** the suite lacks: `verify` returns `false` for tampered/cross‑context/infinity/subgroup‑invalid inputs; opt‑in `slashCommitment` rejects a repeated identical commitment; Merkle rejects forged leaves; fuzz the slash‑window state machine and the collateral accounting invariant (`Σ slashable ≤ collateral`). A formal state‑machine spec of the operator lifecycle should be a release gate.
- **B‑4 (P1):** Establish a **maintenance/ownership plan** for the deployed instance (single‑maintainer risk), including who owns the deployment's `Config` parameters and their published rationale.
- **B‑5 (P1):** Because the contract is immutable, define a **versioning/migration story up front** (a `URCv2` deployment + operator‑migration path), so a future bug or an ePBS‑driven schema change is survivable without stranding collateral.

### Part C — ePBS (EIP‑7732) driven

- **C‑1 (P0, pre‑deploy decision):** Decide whether the `Delegation`/`Commitment` schema must carry a **builder / enforceable‑constraint** notion *before* the immutable deploy, or whether ePBS enforcement is deferred entirely to the slasher layer. Produce a written **URC × ePBS compatibility analysis** (none exists publicly today). This is the highest‑leverage forward‑compat call.
- **C‑2 (P0, Taiko slashers):** Rebuild every fault‑proof that reads block structure/timing (`PreconfSlasherL1/L2`, `LookaheadSlasher`, URC example slashers) for the ePBS block anatomy, payload‑reveal timing, and PTC; re‑validate equivocation/slashing conditions against the Gloas fork‑choice on ePBS devnets. (This is the roadmap's Q4 certification item.)
- **C‑3 (P1):** Parameterize `SLOT_TIME`, `JUSTIFICATION_DELAY`, lookback windows, and beacon genesis (remove hard‑codes) so EIP‑7782 (6s slots) is a parameter change, not a redesign.
- **C‑4 (P2):** Track Fabric's **BALs (EIP‑7928) as commitment substrate** direction; if it becomes the standard, the URC commitment schema (C‑1) should anticipate it.

### Part D — FOCIL (EIP‑7805) driven (Taiko‑side spec)

- **D‑1 (P1):** Define gateway **ordering commitments to coexist with mandatory IL transactions** (a gateway cannot commit to excluding an IL‑forced tx). Spec detail for Hegotá participation; no URC‑contract change.
- **D‑2 (P2):** Re‑derive lookahead window/lookahead math if slots later shorten.

### Part E — Taiko‑side integration changes (`taiko-mono`, not the URC)

- **E‑1 (P1):** Fix the known `LookaheadStore` **§10.2 blacklist‑eligibility bug** (a re‑blacklisted operator reads as eligible because `unBlacklistedAt < ref` is accepted without checking it is the most‑recent transition).
- **E‑2 (P1):** Complete **§10.5 poster‑signature domain separation** (EIP‑712 with chainid + verifying contract); partially addressed by `#21346`.
- **E‑3 (P1):** Harden the `checkProposer` **liveness coupling**: it is called unconditionally inside `propose()` with no gas isolation and no `try/catch`, so a buggy/griefable checker halts the rollup. Add isolation and/or a bounded‑gas contract and a permissionless fallback.
- **E‑4 (P1):** The design doc assumes a **permissionless escape hatch** ("if forced‑inclusion delay exceeded, `Inbox` bypasses proposer checking"); the current `Inbox.sol` calls `checkProposer` **unconditionally** and the permissionless‑delay knobs are stored but never enforced (kimi‑k3 finding I‑01). Add the bypass if the design relies on it.
- **E‑5 (P0):** Re‑pin the URC dependency to the audited tag from B‑2, and reconcile the triplicated, inconsistent **handover‑slot constants** (Go default 8, Rust comment 4, ejector 4) before any of them become on‑chain window logic.

---

## 6. Answering the brief directly

- **Is the URC production‑ready for Taiko today?** No — on process grounds (frozen, unaudited‑at‑HEAD, unpublished reports, zero production use, standard‑BLS fix off‑`main`) **and** on code grounds (two High + three Medium findings, several unpatchable‑after‑deploy).
- **Does ePBS/FOCIL force URC changes?** The Registry **core** needs no mechanical change for either fork. ePBS forces a **schema decision** (builder/constraints in `Delegation`/`Commitment`) that must be made *before* the immutable deploy, and forces a **rebuild of the slasher layer** (Taiko's contracts). FOCIL forces a **gateway‑ordering spec** change, Taiko‑side.
- **If we change the URC, what exactly?** The itemized list is §5. The must‑do‑before‑any‑immutable‑deploy subset is **A‑1, A‑2, A‑3, A‑4, A‑5, A‑7, B‑1, B‑2, C‑1**.
- **Safest path given the timeline:** keep `PreconfWhitelist` until after Glamsterdam; adopt the URC only once the A/B/C‑1 gates are met and an ePBS‑devnet certification exists. Taiko has already, in effect, taken the conservative posture by moving its permissionless stack off `main` (2026‑07‑04) — this review supports keeping it parked until the above gates clear.

---

*This review reflects the URC at `main` HEAD `132bc79`. Findings on the slashing state machine and signed‑message schema are the load‑bearing ones because they cannot be fixed after an immutable deployment. The two audit passes and the crypto pass agree on the chain‑id/domain‑separation and slashing‑replay classes as the highest‑value fixes; the ecosystem review establishes that the deployed‑and‑audited state Taiko would need does not yet exist.*
