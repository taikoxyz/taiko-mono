# InboxOptimized1 bytes26 Collision Risk

## Context
InboxOptimized1 uses a ring buffer to cache recent transition records. To save storage gas, the slot only keeps the first 26 bytes (208 bits) of a parent transition hash when deciding whether a buffered record matches an incoming update. If the truncated value collides, the contract may treat two different parents as the same record until the ring buffer slot is cleared.

## Threat model
- **Targeted second preimage attack:** An adversary controls their transition input and attempts to craft an alternative parent whose Keccak-256 hash shares the same first 26 bytes as an honest parent already cached in the ring buffer.
- **Birthday-style accidental collision:** A large volume of legitimate proposals arrive while the ring buffer still contains earlier entries, leading to an unintended partial hash collision.
- **Post-quantum considerations:** Evaluate the work factor assuming Grover-style quadratic speed-ups for preimage search.

## Computational estimates
- Truncating to bytes26 leaves a 208-bit search space. A brute-force second-preimage requires ~2^208 ≈ 4.1 × 10^62 Keccak evaluations.
- A state-of-the-art classical supercomputer capable of 10^18 hash evaluations/second would need ~4.1 × 10^44 seconds (~1.3 × 10^37 years) of sustained work—orders of magnitude longer than the age of the universe (~1.4 × 10^10 years).
- Even granting a highly optimistic quantum computer running Grover’s algorithm at 10^12 iterations/second, the work factor is ~2^(208/2) ≈ 2.0 × 10^31 iterations, or ~6.4 × 10^11 years of runtime.
- Birthday collision probability after N proposals is ≈ N^2 / 2^(209). With N ≈ 5.3 × 10^5 (one proposal per minute for a year) the probability is ~3.4 × 10^-52. Even with an implausible N = 10^9 proposals in a year, the probability remains ~1.2 × 10^-45.

## Practical risk assessment
- The work required to forge a colliding parent within the one-year finalization window is astronomically high for any classical or near-term quantum adversary. The truncated hash still offers >200 bits of classical security—far above the 128-bit bar generally considered sufficient.
- Accidental collisions are effectively impossible at realistic proposal throughput levels.
- If a collision did occur, the contract would reuse the cached ring-buffer slot and mark a conflicting transition, limiting the blast radius to that proposal slot.

## Recommendation
No practical attack is available under current cryptographic assumptions. The existing bytes26 comparison provides a substantial safety margin while preserving the gas optimization benefit. No change is required beyond documenting the reasoning.
