import Etna.FI.Model
import Etna.Landing.Model
import Lean
open Lean Etna
private def runCase (row : Json) : Except String Json := do
  let id ← row.getObjValAs? String "id"
  let initial ← row.getObjValAs? Nat "initialHead"
  let initialHeight ← row.getObjValAs? Nat "initialHeight"
  let steps ← row.getObjValAs? (Array Nat) "steps"
  let cuts ← row.getObjValAs? (Array Nat) "cuts"
  let feeStrings ← row.getObjValAs? (Array String) "feesGwei"
  let mut values : Array Word64 := #[]
  for s in feeStrings do
    let n ← match s.toNat? with | some n => pure n | none => throw "bad fee"
    let w ← match checkedWord 64 n with | some w => pure w | none => throw "wide fee"
    values := values.push w
  let fee := fun index => values[index-initial]?.getD 0
  let mut head := initial
  let mut height := 0
  let mut paid := 0
  let mut intervals : Array Json := #[]
  for cut in cuts do
    if cut ≤ height || cut > steps.size then throw "invalid cut"
    let before := head
    for index in [height:cut] do
      let consume := steps[index]!
      if consume > 1 then throw "invalid step"
      head ← match FI.advance head (if consume = 1 then some head else none) with
        | .ok n => pure n | .error _ => throw "FI advance rejected"
    let amount := Landing.fees fee before head * 1000000000
    paid := paid + amount
    intervals := intervals.push (Json.mkObj [("before",toJson before),("after",toJson head),
      ("lastHeight",toJson (initialHeight+cut)),("paidWei",toJson (toString amount))])
    height := cut
  if height != steps.size then throw "incomplete cuts"
  pure (Json.mkObj [("id",toJson id),("finalHead",toJson head),
    ("finalHeight",toJson (initialHeight+height)),("paidWei",toJson (toString paid)),("intervals",toJson intervals)])
def main (args : List String) : IO Unit := do
  let path ← match args with | [path] => pure path | _ => throw (IO.userError "one JSONL path required")
  let stdout ← IO.getStdout
  for line in (← IO.FS.readFile path).splitOn "\n" do
    if line.isEmpty then continue
    match Json.parse line >>= runCase with
    | .ok value => stdout.putStrLn value.compress
    | .error e => throw (IO.userError e)
