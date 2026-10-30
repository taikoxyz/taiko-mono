import EtnaModel.Landing

namespace Etna.Design.Encoding
abbrev Byte := Fin 256
abbrev Word := Vector Byte 32

/-- bytes32("TAIKO_ETNA_LAND_V1"), right-padded with zeros. -/
def domain : Word :=
  #v[84,65,73,75,79,95,69,84,78,65,95,76,65,78,68,95,86,49,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

/-- bytes32("ETNA_LAND_CUTS_V1"). -/
def cutDomain : Word :=
  #v[69,84,78,65,95,76,65,78,68,95,67,85,84,83,95,86,49,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

/-- bytes32("ETNA_PARENT_ANCHOR_V1"). -/
def configDomain : Word :=
  #v[69,84,78,65,95,80,65,82,69,78,84,95,65,78,67,72,79,82,95,86,49,0,0,0,0,0,0,0,0,0,0,0]

def ascii (text : String) : List Nat := text.toList.map Char.toNat

/-- Appendix A statement order: 21 static ABI words. -/
structure Statement where
  tag : Word
  l1ChainId : Word
  l2ChainId : Word
  inbox : Word
  registry : Word
  generation : Word
  parentHeight : Word
  parentHash : Word
  parentCometHash : Word
  config : Word
  lastHeight : Word
  lastHash : Word
  lastCometHash : Word
  lastStateRoot : Word
  referenceNumber : Word
  referenceHash : Word
  blobHash : Word
  headBefore : Word
  headAfter : Word
  activeSnapshot : Word
  cutHash : Word
  deriving DecidableEq, Repr

def words (s : Statement) : Vector Word 21 :=
  #v[s.tag,s.l1ChainId,s.l2ChainId,s.inbox,s.registry,s.generation,
    s.parentHeight,s.parentHash,s.parentCometHash,s.config,s.lastHeight,
    s.lastHash,s.lastCometHash,s.lastStateRoot,s.referenceNumber,s.referenceHash,
    s.blobHash,s.headBefore,s.headAfter,s.activeSnapshot,s.cutHash]

def encode (s : Statement) : Vector Byte 672 := (words s).flatten

def wordAt (b : Vector Byte 672) (i : Fin 21) : Word :=
  Vector.ofFn fun j => b[i.val*32+j.val]'(by omega)

def decode (b : Vector Byte 672) : Statement :=
  ⟨wordAt b 0,wordAt b 1,wordAt b 2,wordAt b 3,wordAt b 4,wordAt b 5,
   wordAt b 6,wordAt b 7,wordAt b 8,wordAt b 9,wordAt b 10,wordAt b 11,
   wordAt b 12,wordAt b 13,wordAt b 14,wordAt b 15,wordAt b 16,wordAt b 17,
   wordAt b 18,wordAt b 19,wordAt b 20⟩

def natWord (n : Nat) : Word :=
  Vector.ofFn fun i => ⟨n / 256^(31-i.val) % 256,Nat.mod_lt _ (by decide)⟩

def zeroWord : Word := natWord 0

def flatBytes (ws : List Word) : List Byte := ws.flatMap Vector.toList

/-- cutLeaf preimage abi.encode(uint256(x), blockHash(x), cometHash(x), forcedHead(x)): four words. -/
def leafWords (x : Nat) (c : Cut) : List Word := [natWord x,natWord c.elHash,natWord c.cometHash,natWord c.cursor]

/-- The bytes32 of a leaf: keccak256 of the 128-byte cutLeaf preimage, or the raw word. -/
def leafWord (keccak : List Byte → Word) : Leaf → Word
  | .cut x c => keccak (flatBytes (leafWords x c))
  | .word w => natWord w

/-- abi.encodePacked(leaves): 32 bytes per leaf, empty for h = p+K. -/
def packedLeaves (keccak : List Byte → Word) (leaves : List Leaf) : List Byte :=
  flatBytes (leaves.map (leafWord keccak))

/-- cutHash preimage: tag, generation, p, h and keccak256(abi.encodePacked(leaves)). -/
def cutHashWords (keccak : List Byte → Word) (r : CutHash) : List Word :=
  [cutDomain,natWord r.generation,natWord r.parentHeight,natWord r.lastHeight,keccak (packedLeaves keccak r.leaves)]

/-- land calldata for the cut argument: 32 bytes per leaf. -/
def cutCalldata (keccak : List Byte → Word) (leaves : List Leaf) : Nat := (packedLeaves keccak leaves).length

/-- committeeConfigHash preimage: tag, l2ChainId, registry, vp_unit, s_min, n_max and U —
seven words, 224 bytes. -/
def configWords (l2ChainId registry vpUnit sMin nMax u : Nat) : List Word :=
  [configDomain,natWord l2ChainId,natWord registry,natWord vpUnit,natWord sMin,natWord nMax,natWord u]

/-- Slot 285 word 1 packs the actual parent c, the generation and the FI cursor. Appendix B:
packed fields are laid out in the listed order from the least-significant bit, 48 bits each,
unused high bits zero, and writing a wider value reverts. -/
def packRecord (c generation cursor : Nat) : Nat := c + generation*limit48 + cursor*limit48*limit48

/-- The three slot 285 words; the state root and snapshot are not part of the record. -/
def recordWords (r : Checkpoint) : List Word :=
  [natWord (packRecord r.parent r.generation r.cursor),natWord r.elHash,natWord r.cometHash]

/-- Concrete statement construction from the verified full-range certificate.
Keccak's correctness and local separation are external; byte layouts are proved here. -/
def ofData (d : StatementData) (keccak : List Byte → Word) : Statement :=
  ⟨domain,natWord d.domain.l1ChainId,natWord d.domain.l2ChainId,
   natWord d.domain.inbox,natWord d.domain.registry,natWord d.generation,
   natWord d.input.parentHeight,natWord d.parentHash,natWord d.parentCometHash,
   natWord d.config,natWord d.input.lastHeight,natWord d.input.lastBlockHash,
   natWord d.input.lastCometHash,natWord d.input.lastStateRoot,
   natWord d.input.l1ReferenceBlockNumber,natWord d.referenceHash,
   keccak (d.blobHashes.flatMap (fun h => (natWord h).toList)),
   natWord d.headBefore,natWord d.input.forcedInclusionHead,
   natWord d.input.activeCommitteeSnapshot,
   keccak (flatBytes (cutHashWords keccak d.cutHash))⟩

end Etna.Design.Encoding
