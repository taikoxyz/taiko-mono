import Audit
open Lean Elab Command ZkGasAudit

namespace Fixture
def Claim : Prop := True
theorem exact : Claim := True.intro
theorem weakened : True ∨ Claim := Or.inl True.intro
axiom bad : False
theorem unsound : Claim := bad.elim
end Fixture

run_elab do
  let expectFailure (label : String) (action : CoreM Unit) : CoreM Unit := do
    let failed ← try action; pure false catch _ => pure true
    unless failed do throwError "mutation escaped: {label}"
  checkHeadline `Fixture.exact `Fixture.Claim
  expectFailure "weakened headline" (checkHeadline `Fixture.weakened `Fixture.Claim)
  expectFailure "missing headline" (checkHeadline `Fixture.missing `Fixture.Claim)
  expectFailure "headline on a non-claim" (checkHeadline `Fixture.exact `Fixture.exact)
  expectFailure "extra axiom" (checkAxiomsOf `Fixture.bad)
  expectFailure "axiom behind a headline" (checkHeadline `Fixture.unsound `Fixture.Claim)
  expectFailure "erased claim" (checkAnchors `Fixture.Claim [`Fixture.missing])
  logInfo "audit mutations: exact/weakened/missing/non-claim headlines, axioms, erased anchors OK"
