---
title: IBlobHashReader
---

## IBlobHashReader

_Labeled in AddressResolver as "blob_hash_reader"
This interface and its corresponding implementation may deprecate once
solidity supports the new BLOBHASH opcode natively._

### getFirstBlobHash

```solidity
function getFirstBlobHash() external view returns (bytes32)
```

Returns the versioned hash for the first blob in this
transaction. If there is no blob found, 0x0 is returned.
