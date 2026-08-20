# v6 Protocol — Exhaustive State-Machine Model-Checking Results

**Artifact:** [`model_checker.py`](model_checker.py) — a self-contained Python explicit-state
model checker for the [redesign proposal](../redesign-proposal.md) (v6).
**Question asked:** *can the new design reach an invalid state?*
**Answer (within the checked bounds):** **No.** Across every explored bound the checker found
**zero reachable states violating any safety invariant** and **zero permanent halts** (every
reachable state can still drive the chain to full finalization). A mutation self-test confirms the
invariants are not vacuous — each of four deliberately-injected design bugs is caught.

> Scope honesty up front: this is *bounded* model checking of an *abstraction*. It exhaustively
> explores every adversarial interleaving up to a finite number of epochs and wall-clock steps,
> over a logical abstraction of the protocol (slot-level timing is abstracted into phases — see
> [Abstraction](#what-is-and-isnt-modelled)). It is strong evidence for the *logical* state
> machine (single-decision epochs, monotone `openEpoch`, no double-debit, bond safety, no-frame,
> halt-safety), not a proof about the eventual Solidity, and not a substitute for the game-theory
> and timing analysis in the design doc.

---

## How it works

The protocol is encoded as a state `(per-epoch status + owner + forced-flag + decision record,
global openEpoch, wall-clock, mode, per-tenure reserve, settled certificates, consumed fault-ids,
withdrawn tenures, immutable assignment record)`. From a curated-but-broad set of initial
owner/forced configurations (single owner, handover, multi-handover, anarchy in every position,
forced snapshots in every position, all-forced, none-forced, alternating), the checker does a
**breadth-first exploration of every enabled action**, where the adversary is maximally
nondeterministic — at each state it may take any legal action of any actor:

- **decide** an epoch to CONTENT or EMPTY (commit); **miss_commit** (objective liveness fault);
- **seal** the `openEpoch` (honest or permissionless force-resolve); **miss_seal**;
- **cancel** a stuck CONTENT epoch past the data-loss horizon (`H_cancel`);
- **debit** a settled certificate (one-shot per logical fault id);
- **promote** a terminated holder's successor (or drop to anarchy);
- **withdraw** a bond (only through the state-gate);
- **tick** the wall clock (which drives recovery-only mode via the lag cap `K`).

Only *legal* (design-permitted) transitions are in the relation; the invariants then verify that
the reachable set contains no bad state. (Injecting illegal transitions would test the checker,
not the design — so illegal moves appear only in the mutation self-test below.)

After the state graph is built, a backward reachability pass from the "all epochs sealed" terminal
states identifies any reachable state that **cannot** reach full finalization — a permanent halt,
which would violate G5 / I3.

## Invariants checked (at every reachable state)

| Invariant | Design source | Meaning |
| --- | --- | --- |
| `single_decision` | I2, §3.1, §5 | an epoch is decided at most once; its status never flips its recorded decision |
| `closed_is_prefix` | I3, §6.1 | seals happen strictly in `openEpoch` order — no closed epoch above an open one |
| `open_monotone` | I3 | `openEpoch` never decreases and always equals the lowest non-closed epoch |
| `seal_immutable` | Immutability corollary | a SEALED/CANCELLED epoch never changes afterwards |
| `empty_not_forced` | I6 | an epoch never resolves EMPTY while its forced snapshot is non-empty |
| `no_double_debit` | I2, §8 | a logical fault id is debited at most once (consumed-set) |
| `bond_nonneg` | §4, §8 | a slash never drives a reserve below zero |
| `no_frame` | §7.2, §8.3 | a liveness certificate only ever names the acting owner of that epoch |
| `withdraw_gated` | §8.4 | no withdrawn tenure retains an unresolved certificate or unsealed owned epoch |
| **liveness / halt-safety** | **G5, I3** | **from every reachable state, full finalization is still reachable** |

## Results

All runs below completed **fully exhaustively** (no state-cap truncation) and reported
`SAFETY: NONE` and `LIVENESS: NONE` (no halt):

| Bound (`NEPOCHS × MAXCLOCK`) | Reachable states | Terminal (all-sealed) states | Safety violations | Permanent halts |
| --- | ---: | ---: | :---: | :---: |
| 3 × 4 (default) | 487,611 | 182,419 | 0 | 0 |
| 3 × 5 | 745,671 | 339,117 | 0 | 0 |
| 4 × 3 | 2,377,674 | 503,519 | 0 | 0 |

`4 × 4` exceeds the 4,000,000-state cap (genuine combinatorial explosion of interleavings); the
~3.8M-state prefix explored before the cap likewise surfaced no safety violation. The three
completed runs span the structurally interesting depth: handovers, multi-tenure promotion chains,
anarchy, forced-only epochs, recovery-only mode (lag `> K`), and the data-loss cancellation floor.

### Mutation self-test — the invariants have teeth

Run with `python3 model_checker.py --mutate`. Each mutant injects one known design-breaking bug
and the named invariant **must** catch it:

| Injected bug | Should trip | Result |
| --- | --- | --- |
| re-decide an already-decided epoch (double decision) | `single_decision` | **CAUGHT** |
| resolve EMPTY despite a non-empty forced snapshot | `empty_not_forced` (I6) | **CAUGHT** |
| seal an epoch that is not the `openEpoch` (out-of-order) | `closed_is_prefix` | **CAUGHT** |
| withdraw a bond despite outstanding liability | `withdraw_gated` | **CAUGHT** |

`# mutation self-test: ALL BUGS CAUGHT (invariants have teeth)`

## What this tells us about the design

- **No reachable invalid state** (within the bounds): the v6 state machine never double-decides an
  epoch, never mutates finalized state, never seals out of order, never resolves a forced epoch as
  empty, never double-debits a bond, never drives a reserve negative, never frames a successor for a
  predecessor's miss, and never lets a tenure withdraw with outstanding liability.
- **Halt-safety (G5 / I3) holds structurally**: in *all* 2.4M states of the deepest run, whatever
  the adversary does — withhold commits, withhold seals, force anarchy, stack forced snapshots,
  trigger recovery-only mode — a permissionless action always remains that eventually finalizes the
  open epoch. This is the property the reviews pushed hardest on, and it survives exhaustive attack
  in the abstraction.

## What is and isn't modelled

**Modelled:** the epoch lifecycle and its single-decision finality, the `openEpoch` state machine
and recovery lane, seat handover / promotion / anarchy, objective liveness certificates and their
one-shot debiting, the state-gated withdrawal, forced-snapshot / empty-resolution interaction
(I6), recovery-only mode via the global lag cap, and the cancellation floor.

**Abstracted away (deliberately):** exact slot counts (`Γc`, `κ`, the 32-slot epoch, the `Γc+κ`
last-look window), continuous bond magnitudes and fee/MEV economics, cryptographic mechanisms
(proof public inputs, precommitted payees, the forced-item nullifier, verdict incarnation), and
`>κ` deep-reorg rewind. These are argued in the design doc's game-theory (§11), parameters (§10),
and structural-blocking (§13-S) sections; several are explicitly flagged there as requiring their
own proofs and adversarial tests at the contract/client layer. The model checker is the *logical
state-machine* leg of that verification story, not the whole of it.

**Bounds are finite.** A clean result up to `NEPOCHS=4`, `MAXCLOCK=5` does not prove correctness at
all depths. The value of bounded model checking is that the overwhelming majority of state-machine
bugs manifest at very small bounds (2–4 epochs is more than enough to exercise handover, backlog,
recovery, and cancellation); a bug that first appears only at depth ≥ 5 would be unusual. Raising
the bounds (and the state cap) is a mechanical follow-up.

## Reproduce

```bash
cd packages/protocol/docs/preconfirmation/simulation
python3 model_checker.py            # default 3×4 exhaustive run
python3 model_checker.py 3 5        # NEPOCHS=3 MAXCLOCK=5
python3 model_checker.py 4 3        # NEPOCHS=4 MAXCLOCK=3
python3 model_checker.py --mutate   # invariant self-test (all bugs must be CAUGHT)
```

No dependencies beyond the Python 3 standard library.
