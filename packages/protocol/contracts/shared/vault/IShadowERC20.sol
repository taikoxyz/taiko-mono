// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @custom:security-contact security@taiko.xyz
/// @title  IShadowERC20
/// @notice Interface for ERC20 tokens on Taiko that support Shadow privacy transfers.
///
/// DEPOSIT: Holder sends tokens to targetAddress via a plain ERC20 transfer.
///          No interaction with this interface is required at deposit time.
///
/// PROVE:   ZK circuit proves _balances[targetAddress] >= total_note_amounts
///          using a two-level MPT proof anchored to a block hash.
///          The server computes the storage key as keccak256(abi.encode(targetAddress, balanceSlot())).
///
/// CLAIM:   Shadow.sol calls shadowMint(recipient, amount).
///          New tokens are minted to recipient — no pre-minted reserve, no
///          transfer from targetAddress. Direct analogy to IEthMinter.mintEth.
///
/// GOVERNANCE: Because shadowMint calls _mint, ERC20Votes assigns voting units
///          only if recipient has an active delegate — standard _mint behaviour.
///          targetAddress never called delegate(), so its locked tokens carry
///          no active voting weight.
interface IShadowERC20 {
    error SHADOW_MINT_EXCEEDED();
    /// @notice Returns the Shadow contract authorised to call shadowMint.
    function shadowAddress() external view returns (address shadow_);

    /// @notice Mint tokens to a Shadow claim recipient.
    /// @dev    MUST revert with ShadowUnauthorised if the caller is not authorised.
    ///         MUST mint `_amount` new tokens to `_to` via _mint or equivalent.
    /// @param  _to      Claim recipient (from ZK proof journal).
    /// @param  _amount  Token amount in raw smallest units.
    function shadowMint(address _to, uint256 _amount) external;

    /// @notice Returns the raw ERC20 _balances mapping storage slot index.
    /// @dev    The ZK circuit uses this slot together with the holder address to
    ///         recompute the expected storage key inside the proof, preventing
    ///         a malicious prover from substituting an arbitrary storage key.
    /// @return slot_ The storage slot index (e.g. 0 for plain OZ ERC20).
    function balanceSlot() external pure returns (uint256 slot_);

    /// @notice Returns the maximum amount that may be minted in a single Shadow claim.
    /// @dev    Shadow.sol reads this value and rejects any claim where amount exceeds it.
    ///         The client also reads this value to constrain note amounts in deposit files.
    /// @return maxAmount_ The maximum raw token amount (smallest units) per single claim.
    function maxShadowMintAmount() external view returns (uint256 maxAmount_);
}
