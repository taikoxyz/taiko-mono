------------------ MODULE EtnaRegistryVacancyWitness ------------------
EXTENDS EtnaRegistryVacancy

\* Used only by existential witness profiles. The operational state and
\* frame flag remain exact. The only next-state read of last distinguishes
\* a rejected withdrawn key from the other previous calls. Retain that bit
\* and each endpoint predicate that can distinguish previous calls.
WithdrawnKeyRefusal ==
  /\ last.call.kind = "Register" /\ ~last.accepted
  /\ r.keys[last.call.key].registered
  /\ r.bonds[r.keys[last.call.key].bond].withdrawn

WitnessView ==
  <<r, frameOK, marks, WithdrawnKeyRefusal,
    HeldZeroNotReached, FullRefusalNotReached, ZeroPublicReuseNotReached,
    PartialForfeitNotReached>>

========================================================================
