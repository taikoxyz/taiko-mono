// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ZKStress — single-call stress transaction for zk provers (SP1 / Risc0)
/// @author Daniel (assistant)
/// @notice Call `stress(n)` with one uint to control intensity. The contract
///         intentionally mixes memory writes, keccak hashes, conditional branches,
///         and ecrecover calls to maximize zk proving cost while keeping on-chain
///         semantics simple.
/// @dev This is intentionally gas-expensive if you raise `n`. Be careful on mainnet.
contract ZKStress {

    /// Safety caps (tunable)
    uint256 public constant MAX_MEM_ITER = 2000;    // memory words (32 bytes each)
    uint256 public constant MAX_HASH_ITER = 2000;   // iterations of keccak in main loop
    uint256 public constant MAX_EC = 20;            // number of ecrecover calls max

    /// Single API: impact how much gas & zk-work is done by changing `n`
    /// Internally:
    /// - memIter = min(n, MAX_MEM_ITER)
    /// - hashIter = min(n * 2 / 3, MAX_HASH_ITER)
    /// - ecCount = min(n / 100, MAX_EC)
    ///
    /// Returns a uint accumulator to avoid optimizer removing work.
    function stress(uint256 n) external pure returns (uint256 out) {
        // derive knobs deterministically from n
        uint256 memIter = n;
        if (memIter > MAX_MEM_ITER) memIter = MAX_MEM_ITER;

        uint256 hashIter = (n * 2) / 3;
        if (hashIter == 0 && n > 0) hashIter = 1;
        if (hashIter > MAX_HASH_ITER) hashIter = MAX_HASH_ITER;

        uint256 ecCount = n / 100;
        if (ecCount > MAX_EC) ecCount = MAX_EC;

        // allocate a block of memory and seed it with deterministic values
        // we'll write memIter 32-byte words
        // Use inline assembly for explicit mstore/mload control
        bytes32 seed = keccak256(abi.encodePacked(n)); // deterministic per n

        // Memory pointer: free memory pointer at 0x40
        uint256 base;
        assembly {
            base := mload(0x40)
        }

        // Fill memory with pseudo-random words (cheap on-chain)
        for (uint256 i = 0; i < memIter; ++i) {
            // derive a word
            bytes32 word = keccak256(abi.encodePacked(seed, i));
            // store at base + 32*i
            assembly {
                mstore(add(base, mul(i, 0x20)), word)
            }
            // small accumulate so optimizer can't remove it
            out ^= uint256(word);
        }

        // Main hash + branching loop:
        // iterate hashIter times; load a word from memory
        // compute keccak256(word || i), branch on low bit, and mix into accumulator
        for (uint256 j = 0; j < hashIter; ++j) {
            // pick an index in memory based on j (make access data-dependent)
            uint256 idx = uint256(keccak256(abi.encodePacked(seed, j))) % (memIter == 0 ? 1 : memIter);
            bytes32 memWord;
            assembly {
                memWord := mload(add(base, mul(idx, 0x20)))
            }

            // compute hash of (memWord || j)
            bytes32 h = keccak256(abi.encodePacked(memWord, j));

            // dynamic branch: two different mixing ops
            if ((uint8(h[31]) & 1) == 1) {
                // branch A: xor mix
                out ^= uint256(h);
            } else {
                // branch B: add mix
                unchecked { out += uint256(h); }
            }
        }

        // Merkle-style pairwise hashing phase (in-memory): do a small tree
        // We reuse memory words and perform pairwise keccak until one root.
        // This increases both hashing and memory reads/writes.
        // We'll limit depth so gas stays bounded.
        uint256 active = memIter;
        if (active == 0) {
            // create one word to hash if memIter==0
            bytes32 h0 = keccak256(abi.encodePacked(seed));
            assembly { mstore(base, h0) }
            active = 1;
            out ^= uint256(h0);
        }
        // perform pairwise hashing until active == 1 or for a limited number of rounds
        uint256 rounds = 0;
        while (active > 1 && rounds < 16) {
            uint256 half = active / 2;
            for (uint256 k = 0; k < half; ++k) {
                bytes32 a;
                bytes32 b;
                assembly {
                    let k2 := mul(k, 2)
                    a := mload(add(base, mul(k2, 0x20)))
                    let k2plus1 := add(k2, 1)
                    b := mload(add(base, mul(k2plus1, 0x20)))
                }
                bytes32 hh = keccak256(abi.encodePacked(a, b));
                assembly {
                    mstore(add(base, mul(k, 0x20)), hh)
                }
                out ^= uint256(hh);
            }
            // if odd, move the last element up
            if (active % 2 == 1) {
                bytes32 last;
                assembly {
                    last := mload(add(base, mul(sub(active,1), 0x20)))
                    mstore(add(base, mul(half, 0x20)), last)
                }
            }
            active = half + (active % 2);
            rounds++;
        }

        // Run some ecrecover calls derived from the seed — possibly invalid signatures,
        // but the precompile still executes (costly for zk proving).
        // We generate pseudo r,s,v from keccak outputs.
        bytes32 hashSeed = keccak256(abi.encodePacked(seed, "ecdsa"));
        for (uint256 e = 0; e < ecCount; ++e) {
            bytes32 r = keccak256(abi.encodePacked(hashSeed, e, "r"));
            bytes32 s = keccak256(abi.encodePacked(hashSeed, e, "s"));
            // make v either 27 or 28
            uint8 v = uint8(uint256(keccak256(abi.encodePacked(hashSeed, e, "v"))) & 1) + 27;
            // message hash to pass (32 bytes)
            bytes32 msgHash = keccak256(abi.encodePacked(hashSeed, e, "m"));
            // call ecrecover (returns address(0) for invalid sigs often, but precompile runs)
            address recovered = ecrecover(msgHash, v, r, s);
            // mix recovered into accumulator
            out ^= uint256(uint160(recovered)) | (uint256(v) << 248);
        }

        // final mixing so result depends on everything
        out ^= uint256(keccak256(abi.encodePacked(out, memIter, hashIter, ecCount)));
        return out;
    }
}