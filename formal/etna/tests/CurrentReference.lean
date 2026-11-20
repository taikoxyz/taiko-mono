import EtnaProofs.CurrentCertificate

open Etna.Design Etna.Design.Current.Protocol

-- The certificate is reusable across arbitrary later frontier, registry and image changes.
example (env : Environment) (binding : ReferenceBinding env) (a b : World) (la lb : Landing)
    (same : statement env a la = statement env b lb)
    (cert : Certifies env a (statement env a la)) : Certifies env b (statement env b lb) :=
  equal_statement_certificate_transport binding same cert

-- Operational application requires only raw reference/live storage coherence.
example (env : Environment) (w : World) (image : Hash) (d : StatementData)
    (cert : ImageCertifies env w image d) (fp : CertificateFootprint env w d.input.l1ReferenceBlockNumber) :
    LiveCertifies env w d := image_certificate_live cert fp

example (env : Environment) (w : World) (d : StatementData) (cert : LiveCertifies env w d) :
    d.input.activeCommitteeSnapshot ≤ d.input.l1ReferenceBlockNumber := live_certificate_snapshot_bound cert

-- The operational footprint is derived from history and the bound submitted statement.
example (env : Environment) (registry : Etna.Design.Current.RegistryMachine.State) (w : World) (a : Landing)
    (genesis : Etna.Design.Current.RegistryMachine.Genesis registry)
    (reach : Trace env (empty env registry) w) (cert : Certifies env w (statement env w a)) :
    CertificateFootprint env w a.input.l1ReferenceBlockNumber :=
  certified_statement_footprint genesis reach cert

example (env : Environment) (a b : World) (image : Hash) (d : StatementData)
    (closed : referencePrefix a d.input.l1ReferenceBlockNumber = referencePrefix b d.input.l1ReferenceBlockNumber)
    (cert : ImageCertifies env a image d) : ImageCertifies env b image d :=
  image_certificate_transport rfl closed cert
