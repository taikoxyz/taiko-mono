import EtnaModel.CurrentProtocol

namespace Etna.Design.Current.Protocol

def ClosedStartedMetadata (w : World) : Prop :=
  ∀ s ∈ w.history, s.start.isSome=true → s.inbox.generation=w.inbox.generation →
    w.start=s.start ∧ w.inbox.origin=s.inbox.origin

def ClosedGenerationParameters (w : World) : Prop :=
  ∀ s ∈ w.history, s.inbox.generation=w.inbox.generation →
    parametersOf w.inbox=parametersOf s.inbox

end Etna.Design.Current.Protocol
