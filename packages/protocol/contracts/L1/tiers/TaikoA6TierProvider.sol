// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.20;

import "../../common/EssentialContract.sol";
import "./ITierProvider.sol";

/// @title TaikoA6TierProvider
/// @dev Labeled in AddressResolver as "tier_provider"
/// @dev Assuming liveness bound is 250TKO.
// Taiko token's total supply is 1 billion. Assuming block time is 2 second, and
// the cool down period is 2 days. In 2 days, we can have (2*86400/2)=86400
// blocks. Assuming 10% tokens are used in bonds, then each block may use up to
// these many tokens: 1,000,000,000 * 10% / 86400=1157 TOK per block, which is
// about 722 USD.
contract TaikoA6TierProvider is EssentialContract, ITierProvider {
    error TIER_NOT_FOUND();

    /// @notice Initializes the contract with the provided address manager.
    function init() external initializer {
        __Essential_init();
    }

    function getTier(uint16 tierId) public pure override returns (ITierProvider.Tier memory) {
        if (tierId == LibTiers.TIER_OPTIMISTIC) {
            return ITierProvider.Tier({
                verifierName: "tier_optimistic",
                validityBond: 250 ether, // TKO
                contestBond: 500 ether, // TKO
                cooldownWindow: 24 hours,
                provingWindow: 2 hours,
                maxBlocksToVerify: 10
            });
        }

        if (tierId == LibTiers.TIER_SGX) {
            return ITierProvider.Tier({
                verifierName: "tier_sgx",
                validityBond: 500 ether, // TKO
                contestBond: 1000 ether, // TKO
                cooldownWindow: 24 hours,
                provingWindow: 4 hours,
                maxBlocksToVerify: 8
            });
        }

        if (tierId == LibTiers.TIER_SGX_AND_PSE_ZKEVM) {
            return ITierProvider.Tier({
                verifierName: "tier_sgx_and_pse_zkevm",
                validityBond: 1000 ether, // TKO
                contestBond: 2000 ether, // TKO
                cooldownWindow: 24 hours,
                provingWindow: 6 hours,
                maxBlocksToVerify: 6
            });
        }

        if (tierId == LibTiers.TIER_GUARDIAN) {
            return ITierProvider.Tier({
                verifierName: "tier_guardian",
                validityBond: 0, // must be 0 for top tier
                contestBond: 0, // must be 0 for top tier
                cooldownWindow: 24 hours,
                provingWindow: 8 hours,
                maxBlocksToVerify: 4
            });
        }

        revert TIER_NOT_FOUND();
    }

    function getTierIds() public pure override returns (uint16[] memory tiers) {
        tiers = new uint16[](4);
        tiers[0] = LibTiers.TIER_OPTIMISTIC;
        tiers[1] = LibTiers.TIER_SGX;
        tiers[2] = LibTiers.TIER_SGX_AND_PSE_ZKEVM;
        tiers[3] = LibTiers.TIER_GUARDIAN;
    }

    function getMinTier(uint256 rand) public pure override returns (uint16) {
        // 0.2% will be selected to require PSE zkEVM + SGX proofs.
        if (rand % 500 == 0) return LibTiers.TIER_SGX_AND_PSE_ZKEVM;
        // 10% will be selected to require SGX proofs.
        if (rand % 10 == 0) return LibTiers.TIER_SGX;
        // Other blocks are optimisitc, without validity proofs.
        return LibTiers.TIER_OPTIMISTIC;
    }
}
