import DerivationWitnesses.Examples

namespace TaikoSpec.Derivation.Witness

open Statements

/-- Two sources produce two actual headers with all headline premises satisfied. Both inputs
have missing manifests and therefore exercise permitted empty-block fallback; the earlier
examples separately witness acceptance of forced and proposer manifests. No L1 lookup is
available or needed when the authenticated Etna anchor is unchanged. -/
theorem nonempty_proposal_under_premises :
    InitialParentBounds etnaChain headerProposal headerParent.core ∧
    HeaderPremises etnaChain headerContext headerParent canonicalHistory ∧
    deriveHeaders etnaChain headerProposal headerContext headerParent
      [(source false, none), (source false, none)] = .ok [headerPlan, nextHeaderPlan] ∧
    [headerPlan, nextHeaderPlan].length = 2 := by
  refine ⟨⟨by decide, by decide, by decide⟩, ⟨?_, ?_⟩, rfl, rfl⟩
  · intro a r lookup
    cases lookup
  · intro _ _
    rfl

/-- A nonzero inherited root can still be forged: syntactic checks do not authenticate it. -/
def forgedParent : HeaderParent := { headerParent with beaconRoot := some 29 }

def forgedHeader : HeaderPlan := { headerPlan with beaconRoot := some 29 }
def forgedNextHeader : HeaderPlan := { nextHeaderPlan with beaconRoot := some 29 }

/-- Removing only initial-parent authentication permits a successful two-source proposal
with a noncanonical root, even though all available lookups are sound. This is the reuse
branch: an unavailable lookup cannot repair a forged inherited commitment. -/
theorem forged_initial_root_counterexample :
    LookupsSound headerContext canonicalHistory ∧
    ¬ ParentCommits etnaChain canonicalHistory forgedParent ∧
    deriveHeaders etnaChain headerProposal headerContext forgedParent
      [(source false, none), (source false, none)] = .ok [forgedHeader, forgedNextHeader] ∧
    ¬ HeaderCommits etnaChain canonicalHistory forgedHeader := by
  refine ⟨?_, ?_, rfl, ?_⟩
  · intro a r lookup
    cases lookup
  · intro authenticated
    have bad := authenticated (by decide) (by decide)
    exact (by decide : (some (29 : Root)) ≠ some 17) bad
  · intro authenticated
    have bad := authenticated (by decide)
    exact (by decide : (some (29 : Root)) ≠ some 17) bad

/-- The first Etna child must fetch its root; its pre-Etna parent has no authenticated Etna
commitment obligation. Its effective gas remains 30M across the fork. -/
def firstEtnaParent : HeaderParent :=
  { headerParent with core.timestamp := 1999, core.gasLimit := 31_000_000 }

def forgedLookup : HeaderContext := { headerContext with l1StateRoot := fun _ => some 29 }

def fetchedForgedHeader : HeaderPlan :=
  { forgedHeader with block.timestamp := 2000 }

def fetchedForgedNextHeader : HeaderPlan :=
  { forgedNextHeader with block.timestamp := 2001 }

/-- Removing only lookup soundness permits a successful first-Etna proposal with a wrong
root, followed by reuse of that same wrong root. Initial-parent authentication still holds. -/
theorem unsound_lookup_counterexample :
    ParentCommits etnaChain canonicalHistory firstEtnaParent ∧
    ¬ LookupsSound forgedLookup canonicalHistory ∧
    deriveHeaders etnaChain headerProposal forgedLookup firstEtnaParent
      [(source false, none), (source false, none)] =
        .ok [fetchedForgedHeader, fetchedForgedNextHeader] ∧
    ¬ HeaderCommits etnaChain canonicalHistory fetchedForgedHeader := by
  refine ⟨?_, ?_, rfl, ?_⟩
  · intro etna
    contradiction
  · intro sound
    have bad := sound 400 29 rfl
    exact (by decide : (29 : Root) ≠ 17) bad
  · intro authenticated
    have bad := authenticated (by decide)
    exact (by decide : (some (29 : Root)) ≠ some 17) bad

end TaikoSpec.Derivation.Witness
