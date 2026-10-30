import EtnaVectors.Main

/-! Conformance-vector generator: runs the model's executable transitions over enumerated
scenarios and writes the expected accept/revert and observable state as JSON, and the model's
decisions on the client's pure node rules (`testdata/etna_conformance`). It imports only
the model and nothing imports it. -/
