# Selected current-rule checks

These standard-library Python models check selected rules in the three-document
Etna bundle at `f556fa94186b0ab604573e8d3a4c4d4fa835dc84`. They supplement
historical TLA+/native evidence; they do not update its correspondence or turn
source review into runtime conformance. The current source-only ledger retains
all eleven WAITING implementation obligations.

During the closing review, main advanced to
`3602629758beb653423a23608fd1960810efcfac` in
[PR #22422](https://github.com/taikoxyz/taiko-mono/pull/22422). Its documents
change checkpoint trust, encodings and fork scheduling, including removal of
the L2 fork-time getter. These models retain the exact earlier f556 rules;
they do not establish correspondence to 360262975. The unchanged source
classifier refuses the new bundle rather than granting it execution credit.

The authorized group is Z01–Z07. Each module has its own semantics; only the
bounded explorer and source-identity utility are shared. Snapshot encoding also
uses unchanged historical pure hashing helpers, without invoking the historical
selection engine or granting it current Registry conformance.

| Item | Module | Selected question |
| --- | --- | --- |
| Z01 | `governance.py` | Generation-bound rules/stop changes, recovery carry and same-generation rollback |
| Z02 | `forfeiture.py` | Permanent bond identity, funded pending top-up, exact rounding, self-report ordering and reuse |
| Z03 | `recovery.py` | Issued exclusions, FI blanking, origins and recovery replay |
| Z04 | `snapshot.py` | Canonical positional count/root and the authenticated immutable minimum stake |
| Z05 | `final_snapshot.py` | Final execution-block snapshot versus transaction order |
| Z06 | `origin.py` | Public proven-origin latch versus node and guest checks |
| Z07 | `replacement.py` | Exact acknowledgment and two-chain replacement deadlines |

The [worklist](../WORKLIST.md) records current
completion. Per-item results, defects repaired in the checking tools and the
final group gate are in [REPORT.md](../REPORT.md). The
[plan](../../../docs/superpowers/plans/2026-11-20-etna-current-rule-interleavings.md)
records bounds and original deliverables.

## Reproduction and interpretation

From the repository root, use the configured Python interpreter, with the
standard library available:

```sh
python -I -S -B -m unittest discover -s formal/etna/tests -p 'test_current_*.py' -q
```

Each suite also supports standalone discovery from `formal/etna`, selecting
its exact test filename. Tests establish their repository-relative import path;
no earlier suite or working-tree environment is needed.

The state models declare a finite named action bank. The explorer records every
offered accepted or refused edge and retains shortest paths. It raises on a
state cap or failed assertion; optimized Python refuses before traversal rather
than silently stripping invariant checks. A legal action can be absent from
the bank. The bank's horizon is not a protocol refusal, and a reachability
witness is not a fairness or liveness proof. Z04 exhausts its finite occupancy
patterns and direct byte vectors instead of a transition graph.

`source.source_identity` accepts the exact three raw document streams. It
returns SOURCE_REVIEWED with execution NOT_EVALUATED. The branch's historical
checked-out documentation is a different input and is refused by that current
identity. Neither this metadata nor any old COMPLETE claim establishes current
contract, application or guest behavior.

An owner call passing contract guards does not establish the DAO's separate
finalized-state preauthorization checks. Contract-execution vectors and
compliant-governance histories carry their stated, different premises.

Transaction atomicity, authenticated prior history, L1 inputs/finality, caller
authority, valid proofs and signatures are modeled premises where indicated.
Tiny principal/block fixtures are conditional arithmetic scenarios; they are
not a proved quotient of a deployed system. Numerically legal Q-denominated
configuration vectors are separate from synthetic overflow tests. Byte roots
and configuration hashes do not authenticate their own L1 provenance.

Successful recovery can still leave no usable committee. A valid onchain start
can fail local node or guest checks. An executed L2 replacement whose L1 phase
misses its deadline can leave a permanent split with signing closed. Models
must retain these outcomes; they do not promise automatic recovery or timely
bridge/proof availability. Production, EVM rollback, cryptography, proving,
client/signer integration and deployment readiness remain outside these checks.

## Current-main compatibility

The closing regression uses three distinct document contexts. Both the frozen
f556 snapshot and the historical d183 checkout pass756 ordinary checks,
570/166/20, with no failures, errors or skips. All seven authored suites also
pass separately,110 tests in total.

The actual360 effective merge remains unreviewed and does not pass the broad
regression: two failures and43 errors across the main/conformance cohorts.
All45 failed observations match the no-Z baseline on the same main after
normalizing only random temporary-directory names. The batch's additional
unknown-source test error was fixed without changing the classifier. The
source refusal is retained; a new correspondence assessment is OPEN. The
existing draft is not merge-ready on that newer source.
