# Offchain Specs

Python implementation of offchain specifications for Taiko's based rollup protocol.

## Dependencies

To run these Python modules, install the required dependencies:

```bash
pip install -r requirements.txt
```

## Files

- `Types.py` - Data structures and types
- `BlobDecoder.py` - Handles decoding of proposal data from blobs
- `BlockCalls.py` - Handles system calls for block processing

## Compilation

Python is an interpreted language and doesn't require compilation in the traditional sense. However, you can:

### Syntax Check

To verify syntax without running the code:

```bash
python3 -m py_compile *.py
```

### Type Checking (Optional)

If using type hints, run mypy for static type checking:

```bash
mypy *.py
```

## Usage

These are abstract specifications that must be implemented by the node. The classes provide the interface and logic structure for:

- Decoding blob data into proposals
- Preparing block inputs from various L1/L2 sources
- Managing protocol state through system calls
