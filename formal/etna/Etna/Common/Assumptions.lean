module

public import Etna.Common.Words

public section

namespace Etna

/-! External facts are parameterized propositions, never global axioms. Each proof must
accept the required fact explicitly. These types do not authenticate real-world data. -/

structure InboxAuthentication (Root Inbox Slot Value : Type) where
  root : Root
  inbox : Inbox
  slots : List Slot
  values : List Value
  authentic : Prop

structure RegistryAuthentication (Anchor Snapshot : Type) where
  parentAnchor : Anchor
  snapshot : Snapshot
  authentic : Prop

structure EncodingFacts (Bytes Hash : Type) where
  canonical : Bytes → Prop
  hashesTo : Bytes → Hash → Prop

structure CompletedSingleton (Parent Attributes Tx : Type) where
  parent : Parent
  attributes : Attributes
  transaction : Tx
  retained : List Tx
  completed : Prop
  matchesAuthenticatedContext : Prop

structure ConsensusFacts (Height Validators Certificate : Type) where
  updatesAt : Height → Validators → Prop
  activeAt : Height → Validators → Prop
  validHistory : Prop
  zip215Valid : Certificate → Prop

structure TransactionFacts (State Effects : Type) where
  rollback : State → State → Effects → Prop
  externalFrame : State → State → Effects → Prop
  noAuthorizedMaliciousUpgrade : Prop

/-- A real guest relation is required; DummyProofProvider supplies no such fact. -/
structure GuestSoundness (Statement Batch : Type) where
  verifierAccepts : Statement → Prop
  guestRelation : Statement → Batch → Prop
  sound : ∀ statement, verifierAccepts statement → ∃ batch, guestRelation statement batch

end Etna
