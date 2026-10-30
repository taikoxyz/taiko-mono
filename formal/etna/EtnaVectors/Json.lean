/-! A minimal deterministic JSON renderer for the conformance vectors.

A value is rendered at an indentation depth. `jObj` and `jArr` spread over lines; `jLine`,
`jRow` and `jNats` stay on one line. Keys keep the order they
are written in, so two runs render the same bytes. -/
namespace Etna.Vectors

/-- A JSON value, rendered at an indentation depth. -/
abbrev JVal := Nat → String

def indentation (depth : Nat) : String := "".pushn ' ' (2*depth)

def escapeChar (c : Char) : String :=
  if c = '"' then "\\\"" else if c = '\\' then "\\\\" else if c = '\n' then "\\n" else c.toString

def jStr (s : String) : JVal := fun _ => "\"" ++ String.join (s.toList.map escapeChar) ++ "\""

def jNat (n : Nat) : JVal := fun _ => Nat.repr n

def jBool (b : Bool) : JVal := fun _ => if b then "true" else "false"

def jNull : JVal := fun _ => "null"

def jArr (items : List JVal) : JVal := fun d =>
  if items.isEmpty then "[]" else
    "[\n" ++ String.intercalate ",\n" (items.map fun v => indentation (d+1) ++ v (d+1)) ++ "\n" ++
      indentation d ++ "]"

def jObj (fields : List (String × JVal)) : JVal := fun d =>
  if fields.isEmpty then "{}" else
    "{\n" ++ String.intercalate ",\n" (fields.map fun (k, v) => indentation (d+1) ++ jStr k 0 ++ ": " ++ v (d+1)) ++
      "\n" ++ indentation d ++ "}"

/-- A one-line object. -/
def jLine (fields : List (String × JVal)) : JVal := fun _ =>
  "{" ++ String.intercalate ", " (fields.map fun (k, v) => jStr k 0 ++ ": " ++ v 0) ++ "}"

/-- A one-line array. -/
def jRow (items : List JVal) : JVal := fun _ => "[" ++ String.intercalate ", " (items.map fun v => v 0) ++ "]"

/-- A one-line array of numbers. -/
def jNats (xs : List Nat) : JVal := fun _ => "[" ++ String.intercalate ", " (xs.map Nat.repr) ++ "]"

end Etna.Vectors
