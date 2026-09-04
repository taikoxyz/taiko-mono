// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPermit2
/// @notice Minimal interface for Uniswap's Permit2 `SignatureTransfer` flow, covering only the
/// single-token transfer this repository uses.
/// @dev Permit2 is an immutable contract deployed at the same address on every chain via the
/// deterministic deployer. Only the members needed here are declared; see
/// https://github.com/Uniswap/permit2 for the full interface.
/// @custom:security-contact security@taiko.xyz
interface IPermit2 {
    /// @notice The token and amount a signature authorizes.
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    /// @notice The signed permit message for a single token transfer.
    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice The recipient and amount of a transfer authorized by a signature.
    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    /// @notice Transfers a token using a signed permit message.
    /// @dev Reverts if the signature is invalid, replayed, or past its deadline.
    /// @param permit The permit data signed over by the owner.
    /// @param transferDetails The recipient and amount of the transfer.
    /// @param owner The owner of the tokens, and the signer of the permit.
    /// @param signature The owner's EIP-712 signature over `permit`.
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    )
        external;
}
