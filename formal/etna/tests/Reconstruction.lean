import EtnaWitnesses.Regressions.Reconstruction

open Etna.Design Etna.Design.Reconstruction

example : ReconstructionRegression.overlapResult = some ReconstructionRegression.settled :=
  ReconstructionRegression.overlap_succeeds

example : ReconstructionRegression.recoveredResult = some ReconstructionRegression.recovered :=
  ReconstructionRegression.recovery_origin_succeeds

example : ReconstructionRegression.missingResult = none :=
  ReconstructionRegression.missing_rejected

example {el : Primitives} {start : Rebuilt} {records : List Record} {a b : Rebuilt}
    (left : reconstruct el start records = some a) (right : reconstruct el start records = some b) :
    a = b := trace_unique left right

example : ProjectionTrace ReconstructionRegression.el ReconstructionRegression.laws ReconstructionRegression.initial
    [.landing ReconstructionRegression.first,.landing ReconstructionRegression.second,
     .recovery ReconstructionRegression.recovery,.landing ReconstructionRegression.third]
    ReconstructionRegression.recovered := ReconstructionRegression.actual_certified_trace

example : ReconstructionRegression.recovered.applied = [1,2,3,4,5,6] := by decide +kernel

example {el : Primitives} {laws : ProjectionLaws el} {s : Rebuilt} {l : Landing}
    (cert : Certification el laws s l) :
    ∃ t, step el s (.landing l) = some t ∧ t.checkpoint = cert.after.checkpoint ∧
      el.stateRoot t.state = l.input.lastStateRoot ∧ t.generation = s.generation ∧ t.origin = s.origin ∧
      t.applied = s.applied ++ List.range' (s.checkpoint.height+1) (l.input.lastHeight-s.checkpoint.height) ∧
      Stored el t.baseHeight ⟨t.checkpoint.height,t.checkpoint.elHash⟩ t.state t.archive := certified_result cert

example : reconstruct ReconstructionRegression.el ReconstructionRegression.initial
    [.landing ReconstructionRegression.first,.landing ReconstructionRegression.second,
     .recovery ReconstructionRegression.recovery,.recovery ReconstructionRegression.repeatedRecovery] =
      some ReconstructionRegression.afterRepeatedRecovery := ReconstructionRegression.same_block_recoveries.2.2.2.2

example : reconstructPublic ReconstructionRegression.el ReconstructionRegression.start
    (ReconstructionRegression.headerBytes 0) (ReconstructionRegression.stateImage 0)
    [.landing ReconstructionRegression.first,.landing ReconstructionRegression.second,
     .recovery ReconstructionRegression.recovery,.landing ReconstructionRegression.third] =
      some ReconstructionRegression.recovered := ReconstructionRegression.certified_reconstruction

example : reconstructPublic ReconstructionRegression.el ReconstructionRegression.start
    (ReconstructionRegression.headerBytes 0) (ReconstructionRegression.stateImage 1) [] = none := by decide +kernel

example : reconstructPublic ReconstructionRegression.el { ReconstructionRegression.start with ruleVersion := 2 }
    (ReconstructionRegression.headerBytes 0) (ReconstructionRegression.stateImage 0) [] = none := by decide +kernel
