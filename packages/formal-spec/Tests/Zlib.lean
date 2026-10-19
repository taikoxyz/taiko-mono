import TaikoSpec.Zlib

/-!
# zlib and DEFLATE tests

Cases the shared corpus does not cover. The last three streams come from the Rust driver's
`zlib_rejects_invalid_distances_and_incomplete_trees` test: Go and C zlib reject them,
miniz_oxide accepts them.
-/

open TaikoSpec

/-- `Zlib.decompress` applied to a hex string. -/
def inflateHex (s : String) : Option ByteArray :=
  (fromHex? s).bind Zlib.decompress

-- zlib: a well-formed stream ("hello") decodes; bytes after the trailer are ignored.
#guard (inflateHex "789ccb48cdc9c90700062c0215").map toHex == some "68656c6c6f"
#guard (inflateHex "789ccb48cdc9c90700062c0215ff").map toHex == some "68656c6c6f"
-- zlib: a missing or corrupted trailer, or a truncated stream, is rejected.
#guard (inflateHex "789ccb48cdc9c90700062c02").isNone
#guard (inflateHex "789ccb48cdc9c90700062c0216").isNone
#guard (inflateHex "789ccb48cdc9c907").isNone
-- zlib: a wrong compression method or header checksum is rejected.
#guard (inflateHex "799ccb48cdc9c90700062c0215").isNone
#guard (inflateHex "789dcb48cdc9c90700062c0215").isNone
-- DEFLATE: a stored block copies LEN bytes and requires NLEN to be LEN's one's complement.
#guard (inflateHex "7801010500faff68656c6c6f062c0215").map toHex == some "68656c6c6f"
#guard (inflateHex "7801010500fbff68656c6c6f062c0215").isNone
-- DEFLATE: block type 3 is reserved (the trailer here is the Adler-32 of empty output).
#guard (inflateHex "789c0700000001").isNone
-- DEFLATE: streams Go and C zlib reject but miniz_oxide accepts.
#guard (inflateHex "789c03020000030001").isNone
#guard (inflateHex "789c04a0810800000000e46f7d00c012939201024d0127").isNone
#guard (inflateHex "789c0d80014100000082b602ff3f68d8010608140250").isNone
