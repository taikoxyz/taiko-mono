import EtnaProofs.NormalSigning
import EtnaProofs.Permanence

open Etna.Design

-- Normal provenance must remain connected to the original complete machine.
example {initial finish : ProtocolState.World} (run : NormalSigning.Run initial finish) :
    ProtocolState.Trace initial finish := NormalSigning.run_trace run

-- Confirmation coverage is derived from the whole normal run, not assumed at its end.
example {initial confirmed : ProtocolState.World} (run : NormalSigning.Run initial confirmed)
    (initialCoverage : SigningEscrow.Covered initial) : SigningEscrow.Covered confirmed :=
  NormalSigning.run_covered run initialCoverage

-- Cross-generation provenance derives the actual selected-cutoff bound.
example {confirmed view : ProtocolState.World} (p : SigningBridge.TrustedPrefix view)
    (source : NormalSigning.ConfirmationSource confirmed view p)
    (below : confirmed.inbox.snapshot < confirmed.l1Block)
    (message : SigningBridge.SignMessage) (next : message.height = p.tip.height+1) :
    confirmed.inbox.snapshot ≤ (Consensus.activeAt p.rules.consensus message.height).cutoff :=
  NormalSigning.confirmation_source_bound p source below message next
