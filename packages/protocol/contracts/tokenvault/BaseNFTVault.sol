// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./BaseVault.sol";

/// @title BaseNFTVault
/// @notice Abstract contract for bridging NFTs across different chains.
/// @custom:security-contact security@taiko.xyz
abstract contract BaseNFTVault is BaseVault {
    // Struct representing the canonical NFT on another chain.
    struct CanonicalNFT {
        // Chain ID of the NFT.
        uint64 chainId;
        // Address of the NFT contract.
        address addr;
        // Symbol of the NFT.
        string symbol;
        // Name of the NFT.
        string name;
    }

    // Struct representing the details of a bridged token transfer operation.
    struct BridgeTransferOp {
        // Destination chain ID.
        uint64 destChainId;
        // The owner of the bridge message on the destination chain.
        address destOwner;
        // Recipient address.
        address to;
        // Address of the token.
        address token;
        // IDs of the tokens to transfer.
        uint256[] tokenIds;
        // Amounts of tokens to transfer.
        uint256[] amounts;
        // Gas limit for the operation.
        uint256 gasLimit;
        // Processing fee for the relayer.
        uint256 fee;
        // Address for refund, if needed.
        address refundTo;
        // Optional memo.
        string memo;
    }

    // Constants for interface IDs.
    bytes4 public constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 public constant ERC721_INTERFACE_ID = 0x80ac58cd;
    uint256 public constant MAX_TOKEN_PER_TXN = 10;

    // Mapping to store bridged NFTs and their canonical counterparts.
    mapping(address btoken => CanonicalNFT cannonical) public bridgedToCanonical;

    // Mapping to store canonical NFTs and their bridged counterparts.
    mapping(uint256 chainId => mapping(address ctoken => address btoken)) public canonicalToBridged;

    uint256[48] private __gap;

    event BridgedTokenDeployed(
        uint64 indexed chainId,
        address indexed ctoken,
        address indexed btoken,
        string ctokenSymbol,
        string ctokenName
    );

    event TokenSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint64 destChainId,
        address ctoken,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event TokenReleased(
        bytes32 indexed msgHash,
        address indexed from,
        address ctoken,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event TokenReceived(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint64 srcChainId,
        address ctoken,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    error VAULT_INVALID_TOKEN();
    error VAULT_INVALID_AMOUNT();
    error VAULT_INVALID_TO();
    error VAULT_INTERFACE_NOT_SUPPORTED();
    error VAULT_TOKEN_ARRAY_MISMATCH();
    error VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();

    modifier withValidOperation(BridgeTransferOp memory _op) {
        if (_op.tokenIds.length != _op.amounts.length) {
            revert VAULT_TOKEN_ARRAY_MISMATCH();
        }

        if (_op.tokenIds.length > MAX_TOKEN_PER_TXN) {
            revert VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();
        }

        if (_op.token == address(0)) revert VAULT_INVALID_TOKEN();
        _;
    }
}
