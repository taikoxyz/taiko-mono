import EtnaModel.Landing

namespace Etna.Design.Encoding
abbrev Byte := Fin 256
abbrev Word := Vector Byte 32

/-- bytes32("ETNA_PARENT_ANCHOR_V1"). -/
def configDomain : Word :=
  #v[69,84,78,65,95,80,65,82,69,78,84,95,65,78,67,72,79,82,95,86,49,0,0,0,0,0,0,0,0,0,0,0]

def natWord (n : Nat) : Word :=
  Vector.ofFn fun i => ⟨n / 256^(31-i.val) % 256,Nat.mod_lt _ (by decide)⟩

/-- committeeConfigHash preimage: tag, l2ChainId, registry, vp_unit, s_min, n_max and U —
seven words, 224 bytes. -/
def configWords (l2ChainId registry vpUnit sMin nMax u : Nat) : List Word :=
  [configDomain,natWord l2ChainId,natWord registry,natWord vpUnit,natWord sMin,natWord nMax,natWord u]

end Etna.Design.Encoding
