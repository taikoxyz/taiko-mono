import ZkGasModel

/-!
# Trace checker entry point

`lake exe check-traces <corpus-dir>` will re-check the per-step zk gas traces of
`testdata/zk_gas_vectors` against the model. Not implemented yet: it reports so and succeeds.
-/

def main (_args : List String) : IO UInt32 := do
  IO.println "check-traces: not implemented"
  return 0
