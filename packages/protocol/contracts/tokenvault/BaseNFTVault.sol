// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC721Receiver } from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { IERC1155Receiver } from
    "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from
    "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Proxied } from "../common/Proxied.sol";
import { BaseVault } from "./BaseVault.sol";
import { IBridge } from "../bridge/IBridge.sol";
/**
 * This vault is a parent contract for ERC721 and ERC1155 vaults.
 */

abstract contract BaseNFTVault is BaseVault {
    struct CanonicalNFT {
        uint256 srcChainId;
        address tokenAddr;
        string symbol;
        string name;
        string uri;
    }

    struct BridgeTransferOp {
        uint256 destChainId;
        address to;
        address token;
        string baseTokenUri;
        uint256 tokenId;
        uint256 amount;
        uint256 gasLimit;
        uint256 processingFee;
        address refundAddress;
        string memo;
    }

    // Tracks if a token on the current chain is a canonical or bridged token.
    mapping(address tokenAddress => bool isBridged) public isBridgedToken;

    // Mappings from bridged tokens to their canonical tokens.
    mapping(address bridgedAddress => CanonicalNFT canonicalNft) public
        bridgedToCanonical;

    // Mappings from canonical tokens to their bridged tokens.
    // Also storing chainId for tokens across other chains aside from Ethereum.
    mapping(
        uint256 chainId
            => mapping(address canonicalAddress => address bridgedAddress)
    ) public canonicalToBridged;

    uint256[46] private __gap;

    /**
     * @dev Map canonical token with a bridged address
     * @param bridgedToken The bridged token contract address
     * @param canonical The canonical NFT
     */
    function setBridgedToken(
        address bridgedToken,
        CanonicalNFT memory canonical
    )
        internal
    {
        isBridgedToken[bridgedToken] = true;
        bridgedToCanonical[bridgedToken] = canonical;
        canonicalToBridged[canonical.srcChainId][canonical.tokenAddr] =
            bridgedToken;
    }

    /**
     * @dev Checks if token is invalid, or message is not failed and reverts in
     * case otherwise returns the message hash
     * @param message The bridged message struct data
     * @param proof The proof bytes
     * @param tokenAddress The token address to be checked
     */
    function msgHashIfValidRequest(
        IBridge.Message calldata message,
        bytes calldata proof,
        address tokenAddress
    )
        internal
        view
        returns (bytes32 msgHash)
    {
        IBridge bridge = IBridge(resolve("bridge", false));
        msgHash = bridge.hashMessage(message);

        if (tokenAddress == address(0)) revert VAULT_INVALID_TOKEN();

        if (!bridge.isMessageFailed(msgHash, message.destChainId, proof)) {
            revert VAULT_MESSAGE_NOT_FAILED();
        }
    }
}
