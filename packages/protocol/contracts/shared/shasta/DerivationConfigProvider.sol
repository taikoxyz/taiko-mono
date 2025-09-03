// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IDerivationConfigProvider } from "./IDerivationConfigProvider.sol";

/// @title DerivationConfigProvider
/// @notice Implementation of IDerivationConfigProvider that returns derivation configuration
/// constants
/// @custom:security-contact security@taiko.xyz
contract DerivationConfigProvider is IDerivationConfigProvider {
    /// @inheritdoc IDerivationConfigProvider
    function getDerivationConfig() external pure returns (Config memory) {
        return Config({
            // 4 blobs: EIP-4844 allows max 6 blobs per L1 block. Using 4 leaves room for other
            // rollups/users while providing 512KB of data capacity per proposal.
            proposalMaxBlobs: 4,
            // 524,288 bytes: Each blob is 131,072 bytes (128KB) * 4 blobs = 512KB total.
            // This provides sufficient throughput for L2 blocks while staying within L1 blob
            // limits.
            proposalMaxBytes: 131_072 * 4,
            // 384 blocks: Assuming 1-second block time (aggressive case), this covers an entire
            // Ethereum epoch (384 slots * 12 seconds = 76.8 minutes). Ensures proposals can span
            // reasonable time periods without excessive proof generation costs.
            proposalMaxBlocks: 384,
            // 8,192 transactions: 4096 base * 2 multiplier. Bounds worst-case proving costs as each
            // transaction requires signature verification and state updates. Prevents DoS via
            // proposals with excessive transaction counts.
            blockMaxRawTransactions: 4096 * 2,
            // 128 blocks: ~25.6 minutes at 12s block time. Prevents proposals from anchoring to
            // very old L1 states, ensuring L2 stays reasonably synchronized with L1 while allowing
            // flexibility during L1 congestion.
            anchorMaxOffset: 128,
            // 384 seconds: 12 seconds * 32 = 6.4 minutes. Allows timestamp flexibility for
            // sequencing while preventing proposals from setting timestamps too far in the past,
            // which could enable timestamp manipulation attacks.
            timestampMaxOffset: 12 * 32,
            // 10 permyriad: 10/10,000 = 0.1% max change per block. Prevents dramatic gas limit
            // swings that could destabilize the network or enable economic attacks, while still
            // allowing gradual adjustment to network demand.
            maxBlockGasLimitChangePermyriad: 10,
            // 15,000,000 gas: Roughly half of Ethereum's current 30M limit. Ensures blocks can
            // always process essential operations like deposits/withdrawals even if gas limit
            // is manipulated downward over time.
            minBlockGasLimit: 15_000_000
        });
    }
}
