import EtnaModel.Common

/-! §3.2 fee routing: `extraData = [100 | uint48 generation | uint48 anchor]` and basefee
sharing at 100, so every basefee and priority fee is credited to the block's beneficiary at
L2 execution. The beneficiary is the proposer's own fee recipient and is not checked; no
registry field, L1 vault, receipt or claim exists. EVM gas accounting is an EL boundary. -/
namespace Etna.Design.Fees

/-- Fixed-width big-endian bytes. -/
def be : Nat → Nat → List Nat
  | 0, _ => []
  | w+1, n => be w (n/256) ++ [n%256]

def beValue (bytes : List Nat) : Nat := bytes.foldl (fun acc b => acc*256+b) 0

/-- 13-byte extraData. -/
def extraData (share generation anchor : Nat) : List Nat := share :: (be 6 generation ++ be 6 anchor)

def decodeExtra : List Nat → Option (Nat × Nat × Nat)
  | share :: rest =>
    if rest.length = 12 then some (share,beValue (rest.take 6),beValue (rest.drop 6)) else none
  | [] => none

/-- Credits of one transaction under basefee sharing `share`: (beneficiary, treasury).
Priority fees always go to the beneficiary. -/
def credits (share baseFee priority gasUsed : Nat) : Nat × Nat :=
  let base := baseFee*gasUsed
  (priority*gasUsed + base*share/100, base - base*share/100)

def charged (baseFee priority gasUsed : Nat) : Nat := (baseFee+priority)*gasUsed

structure Tx where
  sender : Nat
  priority : Nat
  gasUsed : Nat
  deriving DecidableEq, Repr

def blockCredits (share baseFee : Nat) (txs : List Tx) : Nat × Nat :=
  txs.foldr (fun tx acc =>
    let c := credits share baseFee tx.priority tx.gasUsed
    (acc.1+c.1,acc.2+c.2)) (0,0)

def blockCharged (baseFee : Nat) (txs : List Tx) : Nat :=
  (txs.map fun tx => charged baseFee tx.priority tx.gasUsed).sum

end Etna.Design.Fees
