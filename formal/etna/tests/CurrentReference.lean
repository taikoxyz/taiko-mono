import EtnaProofs.CurrentCertificate

open Etna.Design Etna.Design.Current.Protocol

-- The certificate is reusable across arbitrary later frontier, registry and image changes.
example (env : Environment) (binding : ReferenceBinding env) (a b : World) (la lb : Landing)
    (same : statement env a la = statement env b lb)
    (cert : Certifies env a (statement env a la)) : Certifies env b (statement env b lb) :=
  equal_statement_certificate_transport binding same cert

-- Operational application requires only raw reference/live storage coherence.
example (env : Environment) (w : World) (image : Hash) (d : StatementData)
    (cert : ImageCertifies env w image d) : LiveCertifies env w d := image_certificate_live cert

example (env : Environment) (w : World) (d : StatementData) (cert : LiveCertifies env w d) :
    d.input.activeCommitteeSnapshot ≤ d.input.l1ReferenceBlockNumber := live_certificate_snapshot_bound cert
