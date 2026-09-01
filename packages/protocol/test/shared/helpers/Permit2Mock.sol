// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IPermit2 } from "src/shared/vault/IPermit2.sol";

/// @notice A faithful stand-in for Uniswap's Permit2 `SignatureTransfer` flow, reproducing its
/// EIP-712 domain, typehashes and signature checks so tests exercise the real signing scheme.
/// @dev The domain separator is derived from `address(this)` at call time rather than cached in an
/// immutable, so this mock keeps working after `vm.etch` places its runtime code at Permit2's
/// canonical address. Permit2's unordered nonce bitmap is simplified to a used/unused flag, which
/// is enough to cover replay.
contract Permit2Mock {
    using SafeERC20 for IERC20;

    bytes32 private constant _EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    bytes32 private constant _TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 private constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    mapping(address owner => mapping(uint256 nonce => bool used)) public nonceUsed;

    error InvalidAmount();
    error InvalidNonce();
    error InvalidSignature();
    error InvalidSignatureLength();
    error SignatureExpired();

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(_EIP712_DOMAIN_TYPEHASH, keccak256("Permit2"), block.chainid, address(this))
        );
    }

    /// @dev Mirrors Permit2's `permitTransferFrom`. `spender` is bound to `msg.sender`, so a
    /// signature made for one spender cannot be redeemed by another.
    function permitTransferFrom(
        IPermit2.PermitTransferFrom calldata permit,
        IPermit2.SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    )
        external
    {
        if (block.timestamp > permit.deadline) revert SignatureExpired();
        if (transferDetails.requestedAmount > permit.permitted.amount) revert InvalidAmount();
        if (nonceUsed[owner][permit.nonce]) revert InvalidNonce();
        nonceUsed[owner][permit.nonce] = true;

        if (_recover(hashTypedData(permit, msg.sender), signature) != owner) {
            revert InvalidSignature();
        }

        IERC20(permit.permitted.token)
            .safeTransferFrom(owner, transferDetails.to, transferDetails.requestedAmount);
    }

    /// @dev Builds the EIP-712 digest a signer must sign for `permit` redeemed by `spender`.
    function hashTypedData(
        IPermit2.PermitTransferFrom calldata permit,
        address spender
    )
        public
        view
        returns (bytes32)
    {
        bytes32 permissions = keccak256(
            abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted.token, permit.permitted.amount)
        );
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TRANSFER_FROM_TYPEHASH, permissions, spender, permit.nonce, permit.deadline
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));
    }

    function _recover(
        bytes32 _digest,
        bytes calldata _signature
    )
        private
        pure
        returns (address)
    {
        if (_signature.length != 65) revert InvalidSignatureLength();

        bytes32 r = bytes32(_signature[0:32]);
        bytes32 s = bytes32(_signature[32:64]);
        uint8 v = uint8(_signature[64]);

        address signer = ecrecover(_digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        return signer;
    }
}
