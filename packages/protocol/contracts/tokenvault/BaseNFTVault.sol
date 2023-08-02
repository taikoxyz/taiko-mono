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
import { IBridge } from "../bridge/IBridge.sol";

abstract contract BaseNFTVault is EssentialContract {
    struct CanonicalNFT {
        uint256 chainId;
        address addr;
        string symbol;
        string name;
    }

    struct BridgeTransferOp {
        uint256 destChainId;
        address to;
        address token;
        uint256[] tokenIds;
        uint256[] amounts;
        uint256 gasLimit;
        uint256 processingFee;
        address refundAddress;
        string memo;
    }

    bytes4 public constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 public constant ERC721_INTERFACE_ID = 0x80ac58cd;

    // Tracks if a token on the current chain is a ctoken or btoken.
    mapping(address tokenAddress => bool isBridged) public isBridgedToken;

    // Mappings from btokens to their ctoken tokens.
    mapping(address btoken => CanonicalNFT ctoken) public bridgedToCanonical;

    // Mappings from ctoken tokens to their btokens.
    // Also storing chainId for tokens across other chains aside from Ethereum.
    mapping(uint256 chainId => mapping(address ctokenAddress => address btoken))
        public canonicalToBridged;

    uint256[47] private __gap;

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

    /**
     * Thrown when the `to` address in an operation is invalid.
     * This can happen if it's zero address or the address of the token vault.
     */
    error VAULT_INVALID_TO();

    /**
     * Thrown when the token address in a transaction is invalid.
     * This could happen if the token address is zero or doesn't conform to the
     * ERC20 standard.
     */
    error VAULT_INVALID_TOKEN();

    /**
     * Thrown when the amount in a transaction is invalid.
     * This could happen if the amount is zero or exceeds the sender's balance.
     */
    error VAULT_INVALID_AMOUNT();

    /**
     * Thrown when the owner address in a message is invalid.
     * This could happen if the owner address is zero or doesn't match the
     * expected owner.
     */
    error VAULT_INVALID_OWNER();

    /**
     * Thrown when the sender in a message context is invalid.
     * This could happen if the sender isn't the expected token vault on the
     * source chain.
     */
    error VAULT_INVALID_SENDER();

    /**
     * Thrown when the source chain ID in a message is invalid.
     * This could happen if the source chain ID doesn't match the current
     * chain's ID.
     */
    error VAULT_INVALID_SRC_CHAIN_ID();

    /**
     * Thrown when the interface (ERC1155/ERC721) is not supported.
     */
    error VAULT_INTERFACE_NOT_SUPPORTED();

    /**
     * Thrown when a message has not failed.
     * This could happen if trying to release a message deposit without proof of
     * failure.
     */
    error VAULT_MESSAGE_NOT_FAILED();

    /**
     * Thrown when a message has already released
     */
    error VAULT_MESSAGE_RELEASED_ALREADY();

    /**
     * Thrown when the length of the tokenIds array and the amounts
     * array differs.
     */
    error VAULT_TOKEN_ARRAY_MISMATCH();

    /**
     * Thrown when more tokens are about to be bridged than allowed.
     */
    error VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }
}
