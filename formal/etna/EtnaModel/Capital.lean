import EtnaModel.Committee

/-! Pure launch acceptance from ACCEPTANCE.md §4 (lines 34–36).

These definitions consume the actual selected committee snapshot. `Entry.stake` means
selected effective stake in TAIKO base units; pending deposits and unselected entries are
not inputs. Authentication of that snapshot, the price source/haircut/review policy, and
the common-control classification are external operating evidence. No protocol transition
imports or calls this module: economic shortfalls do not veto consensus or recovery.
-/
namespace Etna.Design.Capital

/-- Number of base units in one TAIKO. Both the capital target and the per-TAIKO reference
price use the same chosen currency precision, so their common currency unit cancels. -/
def tokenScale : Nat := 10^18

/-- Ceiling division on its intended domain `0 < denominator`. The total Nat function's
zero-denominator result has no acceptance meaning; `capitalChecks` rejects zero inputs. -/
def ceilDiv (numerator denominator : Nat) : Nat :=
  (numerator + denominator - 1) / denominator

/-- S_MIN_TOTAL = ceil(3 * C_CAP_MIN * 10^18 / P_REF), in TAIKO base units.
No forfeiture rate or proposed irreversible-loss target enters this formula. -/
def minimumTotalStake (capitalMin priceRef : Nat) : Nat :=
  ceilDiv (3 * capitalMin * tokenScale) priceRef

/-- Sum only the selected entries' effective principal. -/
def selectedStake (selected : List Committee.Entry) : Nat :=
  (selected.map Committee.Entry.stake).sum

/-- Minimum integer voting power able to block a strictly-more-than-two-thirds commit. -/
def blockingPower (totalPower : Nat) : Nat := ceilDiv totalPower 3

/-- Aggregate selected voting power for one externally supplied controller label.
Every selected key receives a label. Known common controllers must share a label;
distinct labels express the supplied classification, not proven independence. Funding
alone does not determine control. Filtering selected entries avoids counting absent keys
or duplicating an entry merely because its label occurs more than once. -/
def commonControlPower (vpUnit : Nat) (selected : List Committee.Entry)
    (controllerOf : Hash → Hash) (controller : Hash) : Nat :=
  Committee.totalPower vpUnit (selected.filter (fun e => decide (controllerOf e.key = controller)))

/-- Each selected entry and every represented known common-control aggregate must have
strictly less than one third of the actual selected total voting power. -/
def concentrationChecks (vpUnit : Nat) (selected : List Committee.Entry)
    (controllerOf : Hash → Hash) : Bool :=
  selected.all (fun e =>
    decide (3 * Committee.power vpUnit e < Committee.totalPower vpUnit selected) &&
    decide (3 * commonControlPower vpUnit selected controllerOf (controllerOf e.key) <
      Committee.totalPower vpUnit selected))

/-- Both independent numerical capital checks, with positive inputs and an externally
validated current valuation. The blocking-value comparison is cross-multiplied by 10^18
to avoid truncating currency values. This does not validate oracle data or review policy. -/
def capitalChecks (capitalMin priceRef vpUnit : Nat) (valuationCurrent : Bool)
    (selected : List Committee.Entry) : Bool :=
  valuationCurrent && decide (0 < capitalMin ∧ 0 < priceRef ∧ 0 < vpUnit ∧
    minimumTotalStake capitalMin priceRef ≤ selectedStake selected ∧
    capitalMin * tokenScale ≤
      blockingPower (Committee.totalPower vpUnit selected) * vpUnit * priceRef)

/-- Scoped numerical part of initial launch acceptance; resource/proof/verifier/signer
acceptance remains separate. A false result during operation calls for operating actions,
not a new block-validity, signing, rotation or recovery guard. -/
def launchAccepted (capitalMin priceRef vpUnit : Nat) (valuationCurrent : Bool)
    (selected : List Committee.Entry) (controllerOf : Hash → Hash) : Bool :=
  capitalChecks capitalMin priceRef vpUnit valuationCurrent selected &&
    concentrationChecks vpUnit selected controllerOf

end Etna.Design.Capital
