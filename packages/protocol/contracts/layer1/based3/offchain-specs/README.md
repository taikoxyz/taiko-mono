# Offchain Specs

Python implementation of offchain specifications for Taiko's based rollup protocol.

## Dependencies

To run these Python modules, install the required dependencies:

```bash
pip install -r requirements.txt
```

## Files

- `Data.py` - Data structures and types
- `BlobDecoder.py` - Handles decoding of proposal data from blobs
- `BlockPreparer.py` - Handles preparation of build block input
- `SystemCall.py` - Handles system calls for block processing

## Usage

These are abstract specifications that must be implemented by the node. The classes provide the interface and logic structure for:

- Decoding blob data into proposals
- Preparing block inputs from various L1/L2 sources
- Managing protocol state through system calls
