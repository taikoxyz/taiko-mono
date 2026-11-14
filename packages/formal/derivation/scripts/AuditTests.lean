import Audit
open Lean Elab Command DerivationAudit

namespace Fixture
structure Premises : Prop where
  needed : True
  unused : True
def Claim : Prop := True
theorem exact : Claim := True.intro
theorem weakened : True ∨ Claim := Or.inl True.intro
theorem live (p : Premises) : True := p.needed
theorem transitive (p : Premises) : True := live p
theorem dead (p : Premises) : True := by
  have _h := p.needed
  exact True.intro
axiom bad : False
end Fixture

run_elab do
  let expectFailure (label : String) (action : CoreM Unit) : CoreM Unit := do
    let failed ← try action; pure false catch _ => pure true
    unless failed do throwError "mutation escaped: {label}"
  expectFailure "trivial premise" ((checkPremiseShape `Fixture.Premises #[`needed, `unused]).run')
  expectFailure "added/removed premise" ((checkPremiseShape `Fixture.Premises #[`needed]).run')
  expectFailure "erased claim" (checkAnchors `Fixture.Claim [`Fixture.Premises])
  checkHeadline `Fixture.exact `Fixture.Claim
  expectFailure "weakened headline" (checkHeadline `Fixture.weakened `Fixture.Claim)
  expectFailure "missing headline" (checkHeadline `Fixture.missing `Fixture.Claim)
  expectFailure "extra axiom" (checkAxiomsOf `Fixture.bad)
  let fields := #[`needed, `unused]
  let live ← (premiseReads `Fixture.Premises fields `Fixture.live).run' {}
  let transitive ← (premiseReads `Fixture.Premises fields `Fixture.transitive).run' {}
  let dead ← (premiseReads `Fixture.Premises fields `Fixture.dead).run' {}
  unless live.contains `needed && transitive.contains `needed do
    throwError "live/transitive premise reads not detected"
  unless !dead.contains `needed do throwError "dead premise read counted"
  expectFailure "unused premise" (checkPremiseUse `Fixture.Premises #[`Fixture.live])
  logInfo "audit mutations: exact/weakened/missing headlines, axioms, live/transitive/dead/unused premises OK"
