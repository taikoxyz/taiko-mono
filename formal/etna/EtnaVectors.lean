import EtnaVectors.Main

/-! Conformance-vector generator: runs the current model's executable transitions over
enumerated scenarios and writes the expected accept/revert and observable state as JSON
(`testdata/etna_current_conformance`). It imports only the model and nothing imports it. -/
