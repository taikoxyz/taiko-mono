// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ZKStress — single-call stress transaction for zk provers (SP1 / Risc0)
/// @author Daniel (assistant)
/// @notice Call `stress(n)` with one uint to control intensity. The contract
///         intentionally mixes memory writes, keccak hashes, conditional branches,
///         and ecrecover calls to maximize zk proving cost while keeping on-chain
///         semantics simple.
/// @dev This is intentionally gas-expensive if you raise `n`. Be careful on mainnet.
/// See tx: https://etherscan.io/tx/0x25c582457205f73c77d30f1b3ee3faf067f37428ae8c6cf43e5ecfb673bb1d7b
contract ZKStress {
    uint256 private constant SECP256K1_N =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    uint256 private constant SECP256K1_N_DIV_2 =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;
    bytes32 private constant ECDSA_LABEL =
        0x6563647361000000000000000000000000000000000000000000000000000000;

    /// Safety caps (tunable)
    uint256 public constant MAX_MEM_ITER = 20_000; // memory words (32 bytes each)
    uint256 public constant MAX_HASH_ITER = 200_000_000_000; // iterations of keccak in main loop
    uint256 public constant MAX_EC = 200_000_000_000; // number of ecrecover calls max
    uint256 private _flag;

    /// Single API: impact how much gas & zk-work is done by changing `n`
    /// Internally:
    /// - memIter = min(n, MAX_MEM_ITER)
    /// - hashIter = min(n * 2 / 3, MAX_HASH_ITER)
    /// - ecCount = min(n / 100, MAX_EC)
    ///
    /// Returns a uint accumulator to avoid optimizer removing work.
    function stress(uint256 n) external returns (uint256 out) {
        _flag = 1;
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
        bytes32 seed;
        assembly {
            mstore(0x00, n)
            seed := keccak256(0x00, 0x20)
        }

        // Reserve scratch space ahead of the stress buffer.
        uint256 scratch;
        uint256 base;
        assembly {
            scratch := mload(0x40)
            base := add(scratch, 0x80)
            mstore(0x40, base)
        }

        // Fill memory with pseudo-random words (cheap on-chain)
        for (uint256 i = 0; i < memIter; ++i) {
            // derive a word
            bytes32 word;
            assembly {
                mstore(scratch, seed)
                mstore(add(scratch, 0x20), i)
                word := keccak256(scratch, 0x40)
            }
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
            bytes32 idxHash;
            assembly {
                mstore(scratch, seed)
                mstore(add(scratch, 0x20), j)
                idxHash := keccak256(scratch, 0x40)
            }
            uint256 idx = uint256(idxHash) % (memIter == 0 ? 1 : memIter);
            bytes32 memWord;
            assembly {
                memWord := mload(add(base, mul(idx, 0x20)))
            }

            // compute hash of (memWord || j)
            bytes32 h;
            assembly {
                mstore(scratch, memWord)
                mstore(add(scratch, 0x20), j)
                h := keccak256(scratch, 0x40)
            }

            // dynamic branch: two different mixing ops
            if ((uint8(h[31]) & 1) == 1) {
                // branch A: xor mix
                out ^= uint256(h);
            } else {
                // branch B: add mix
                unchecked {
                    out += uint256(h);
                }
            }
        }

        // Merkle-style pairwise hashing phase (in-memory): do a small tree
        // We reuse memory words and perform pairwise keccak until one root.
        // This increases both hashing and memory reads/writes.
        // We'll limit depth so gas stays bounded.
        uint256 active = memIter;
        if (active == 0) {
            // create one word to hash if memIter==0
            bytes32 h0;
            assembly {
                mstore(scratch, seed)
                h0 := keccak256(scratch, 0x20)
            }
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
                bytes32 hh;
                assembly {
                    mstore(scratch, a)
                    mstore(add(scratch, 0x20), b)
                    hh := keccak256(scratch, 0x40)
                }
                assembly {
                    mstore(add(base, mul(k, 0x20)), hh)
                }
                out ^= uint256(hh);
            }
            // if odd, move the last element up
            if (active % 2 == 1) {
                bytes32 last;
                assembly {
                    last := mload(add(base, mul(sub(active, 1), 0x20)))
                    mstore(add(base, mul(half, 0x20)), last)
                }
            }
            active = half + (active % 2);
            rounds++;
        }

        // Run some ecrecover calls derived from the seed — possibly invalid signatures,
        // but the precompile still executes (costly for zk proving).
        // We generate pseudo r,s,v from keccak outputs.
        bytes32 hashSeed;
        assembly {
            mstore(scratch, seed)
            mstore(add(scratch, 0x20), ECDSA_LABEL)
            hashSeed := keccak256(scratch, 0x25)
        }
        out = _mixEcrecover(hashSeed, ecCount, out);

        // final mixing so result depends on everything
        bytes32 finalMix;
        assembly {
            mstore(scratch, out)
            mstore(add(scratch, 0x20), memIter)
            mstore(add(scratch, 0x40), hashIter)
            mstore(add(scratch, 0x60), ecCount)
            finalMix := keccak256(scratch, 0x80)
        }
        out ^= uint256(finalMix);

        uint256 memWords = memIter == 0 ? 1 : memIter;
        uint256 used = base + (memWords * 0x20);
        assembly {
            let current := mload(0x40)
            if lt(current, used) {
                mstore(0x40, used)
            }
        }
        return out;
    }

    function _mixEcrecover(
        bytes32 hashSeed,
        uint256 ecCount,
        uint256 out
    )
        private
        pure
        returns (uint256)
    {
        for (uint256 e = 0; e < ecCount; ++e) {
            bytes32 rRaw;
            assembly {
                let freemem := mload(0x40)
                mstore(0x00, hashSeed)
                mstore(0x20, e)
                mstore(0x40, 0)
                mstore8(0x40, 0x72)
                rRaw := keccak256(0x00, 0x41)
                mstore(0x40, freemem)
            }
            bytes32 sRaw;
            assembly {
                let freemem := mload(0x40)
                mstore(0x00, hashSeed)
                mstore(0x20, e)
                mstore(0x40, 0)
                mstore8(0x40, 0x73)
                sRaw := keccak256(0x00, 0x41)
                mstore(0x40, freemem)
            }
            bytes32 vHash;
            assembly {
                let freemem := mload(0x40)
                mstore(0x00, hashSeed)
                mstore(0x20, e)
                mstore(0x40, 0)
                mstore8(0x40, 0x76)
                vHash := keccak256(0x00, 0x41)
                mstore(0x40, freemem)
            }
            uint8 v = uint8(uint256(vHash) & 1) + 27;
            bytes32 msgHash;
            assembly {
                let freemem := mload(0x40)
                mstore(0x00, hashSeed)
                mstore(0x20, e)
                mstore(0x40, 0)
                mstore8(0x40, 0x6d)
                msgHash := keccak256(0x00, 0x41)
                mstore(0x40, freemem)
            }

            uint256 rNum = uint256(rRaw) % SECP256K1_N;
            if (rNum == 0) rNum = 1;
            uint256 sNum = uint256(sRaw) % SECP256K1_N;
            if (sNum == 0) sNum = 1;
            if (sNum > SECP256K1_N_DIV_2) {
                unchecked {
                    sNum = SECP256K1_N - sNum;
                }
            }
            bytes32 rNorm = bytes32(rNum);
            bytes32 sNorm = bytes32(sNum);
            address recovered = ecrecover(msgHash, v, rNorm, sNorm);
            out ^= uint256(uint160(recovered)) | (uint256(v) << 248);
        }
        return out;
    }
}
