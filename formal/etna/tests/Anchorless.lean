import EtnaWitnesses.Regressions.Anchorless

open Etna.Design Etna.Design.Anchorless

-- A readable root must have an actual canonical write, and cannot be in the future.
example {l1 : Nat → Nat} {fork : Nat} {s : RootState} {id root : Nat}
    (history : RootRun l1 fork s) (accepted : resolve fork s true id = some root) :
    ∃ number, root = l1 number := resolved_canonical history accepted

-- The first fork block closes anchorV4 even if its old ancestors check passes.
example (fork : Nat) : anchorV4 fork fork true = false := fork_gate fork

-- Partial paired upgrades revert to the exact prior state.
example (s : Installation) : pairedUpgrade s true false = s := failed_pair_signal s

example : RootRun AnchorlessRegression.l1 AnchorlessRegression.fork AnchorlessRegression.active :=
  AnchorlessRegression.fork_boundary.1

example : CacheRun AnchorlessRegression.l1 AnchorlessRegression.fork AnchorlessRegression.domain
    AnchorlessRegression.verify AnchorlessRegression.expired AnchorlessRegression.received :=
  AnchorlessRegression.cached_after_expiry.1

example : InstallRun AnchorlessRegression.fork AnchorlessRegression.installed := AnchorlessRegression.paired_migration.1

-- Service requests bind explicit chain/app/signal through the fixed deployment adapter.
example : Anchorless.ServiceRun AnchorlessRegression.service AnchorlessRegression.l1
    AnchorlessRegression.fork AnchorlessRegression.serviceVerify
    AnchorlessRegression.expired AnchorlessRegression.serviceCache := AnchorlessRegression.service_history.1
