import EtnaModel.Landing

/-! §3.4 single-block landability and §6.4 / appendix C size and timing arithmetic. These are arithmetic
consequences of the stated constants; real zlib/blob encoders and gas costs are
implementation and measurement boundaries. -/
namespace Etna.Design.Budget

def blobBytes : Nat := 130044
/-- Validity cap on the envelope block item (uncompressed), its RLP list header included. -/
def blockCap : Nat := 124000
/-- Payload list `rlp([executionBlock, …])` of m block items of at most `blockCap` bytes each:
the items total at most m · 124,000 < 2^24 bytes for m ≤ 6, so the list header takes at most
4 bytes. -/
def payloadCap (m : Nat) : Nat := m*blockCap+4

/-- zlib's `deflateBound` at default settings (windowBits 15, memLevel 8), zlib wrapper
included: n + n/2^12 + n/2^14 + n/2^25 + 13. It bounds the compressed size of any n-byte
input, incompressible data included. -/
def deflateBound (len : Nat) : Nat := len+len/4096+len/16384+len/33554432+13

end Etna.Design.Budget
