import EtnaModel.Landing

/-! §3.4 single-block landability and §6.4 / appendix C size and timing arithmetic. These are arithmetic
consequences of the stated constants; real zlib/blob encoders and gas costs are
implementation and measurement boundaries. -/
namespace Etna.Design.Budget

def blobBytes : Nat := 130044
def frameReserve : Nat := 4096
/-- Bytes usable by one payload in one blob: 130,044 − 4 KiB. -/
def blobUsable : Nat := blobBytes-frameReserve
/-- Framing allowance per block (1,024 bytes); the blob payload carries no CometBFT header. -/
def headerFrame : Nat := 1024
/-- Validity cap on the envelope block item (uncompressed). -/
def blockCap : Nat := 124000
def storedBlock : Nat := 65535

/-- zlib stored output: 2-byte header, 5 bytes per ≤65,535-byte block, 4-byte Adler-32. -/
def storedSize (len : Nat) : Nat := len+5*((len+storedBlock-1)/storedBlock)+6

end Etna.Design.Budget
