// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { IERC721Receiver } from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { IERC1155Receiver } from
    "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from
    "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Proxied } from "../common/Proxied.sol";
import { IRecallableMessageSender, IBridge } from "../bridge/IBridge.sol";

/**
 * @title BaseNFTVault
 * @notice Abstract contract for bridging NFTs across different chains.
 */
abstract contract BaseNFTVault is
    EssentialContract,
    IRecallableMessageSender
{
    // Struct representing the canonical NFT on another chain.
    struct CanonicalNFT {
        uint256 chainId; // Chain ID of the NFT.
        address addr; // Address of the NFT contract.
        string symbol; // Symbol of the NFT.
        string name; // Name of the NFT.
    }

    // Struct representing the details of a bridged token transfer operation.
    struct BridgeTransferOp {
        uint256 destChainId; // Destination chain ID.
        address to; // Recipient address.
        address token; // Address of the token.
        uint256[] tokenIds; // IDs of the tokens to transfer.
        uint256[] amounts; // Amounts of tokens to transfer.
        uint256 gasLimit; // Gas limit for the operation.
        uint256 fee; // Processing fee for the relayer.
        address refundTo; // Address for refund, if needed.
        string memo; // Optional memo.
    }

    // Constants for interface IDs.
    bytes4 public constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 public constant ERC721_INTERFACE_ID = 0x80ac58cd;

    // Mapping to track bridged tokens.
    mapping(address => bool) public isBridgedToken;

    // Mapping to store bridged NFTs and their canonical counterparts.
    mapping(address => CanonicalNFT) public bridgedToCanonical;

    // Mapping to store canonical NFTs and their bridged counterparts.
    mapping(uint256 => mapping(address => address)) public canonicalToBridged;

    // Gap for storage layout compatibility.
    uint256[47] private __gap;

    // Events for token bridging and operations.
    event BridgedTokenDeployed(
        uint256 indexed chainId,
        address indexed ctoken,
        address indexed btoken,
        string ctokenSymbol,
        string ctokenName
    );

    event TokenSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event TokenReleased(
        bytes32 indexed msgHash,
        address indexed from,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event TokenReceived(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 srcChainId,
        address token,
        uint256[] tokenIds,
        uint256[] amounts
    );

    // Errors that can be thrown by the contract.
    error VAULT_INVALID_TO();
    error VAULT_INVALID_TOKEN();
    error VAULT_INVALID_AMOUNT();
    error VAULT_INVALID_USER();
    error VAULT_INVALID_FROM();
    error VAULT_INVALID_SRC_CHAIN_ID();
    error VAULT_INTERFACE_NOT_SUPPORTED();
    error VAULT_MESSAGE_NOT_FAILED();
    error VAULT_MESSAGE_RELEASED_ALREADY();
    error VAULT_TOKEN_ARRAY_MISMATCH();
    error VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();

    /**
     * @notice Initialize the contract with an address manager.
     * @param addressManager The address of the address manager.
     */
    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }
}
