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
    /**
     * Thrown when the length of the tokenIds array and the amounts
     * array differs.
     */
    error VAULT_TOKEN_ARRAY_MISMATCH();

    /**
     * Thrown when more tokens are about to be bridged than allowed.
     */
    error VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();

    struct CanonicalNFT {
        uint256 chainId;
        address addr;
        string symbol;
        string name;
        string uri;
    }

    struct BridgeTransferOp {
        uint256 destChainId;
        address to;
        address token;
        string baseTokenUri;
        uint256[] tokenIds;
        uint256[] amounts;
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

    // In order not to gas-out we need to hard cap the nr. of
    uint256 public constant MAX_TOKEN_PER_TXN = 10;
 
    uint256[45] private __gap;

    modifier onlyValidAmounts(
        uint256[] memory amounts,
        uint256[] memory tokenIds,
        bool isERC721
    ) {
        if (tokenIds.length != amounts.length) {
            revert VAULT_TOKEN_ARRAY_MISMATCH();
        }
        
        if (tokenIds.length > MAX_TOKEN_PER_TXN) {
            revert VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();
        }

        if (isERC721) {
            for (uint i; i < tokenIds.length; i++) {
                if(amounts[i] != 1) {
                    revert VAULT_INVALID_AMOUNT();
                }
            }
        }
        else {
            // ERC1155 has slightly diff check
            for (uint i; i < amounts.length; i++) {
                if(amounts[i] == 0) {
                    revert VAULT_INVALID_AMOUNT();
                }
            }
        }
        _;
    }

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
        canonicalToBridged[canonical.chainId][canonical.addr] = bridgedToken;
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

    function extractCalldata(bytes memory calldataWithSelector)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory calldataWithoutSelector;

        assert(calldataWithSelector.length >= 4);

        assembly {
            let totalLength := mload(calldataWithSelector)
            let targetLength := sub(totalLength, 4)
            calldataWithoutSelector := mload(0x40)

            // Set the length of callDataWithoutSelector (initial length - 4)
            mstore(calldataWithoutSelector, targetLength)

            // Mark the memory space taken for callDataWithoutSelector as
            // allocated
            mstore(0x40, add(calldataWithoutSelector, add(0x20, targetLength)))

            // Process first 32 bytes (we only take the last 28 bytes)
            mstore(
                add(calldataWithoutSelector, 0x20),
                shl(0x20, mload(add(calldataWithSelector, 0x20)))
            )

            // Process all other data by chunks of 32 bytes
            for { let i := 0x1C } lt(i, targetLength) { i := add(i, 0x20) } {
                mstore(
                    add(add(calldataWithoutSelector, 0x20), i),
                    mload(add(add(calldataWithSelector, 0x20), add(i, 0x04)))
                )
            }
        }

        return calldataWithoutSelector;
    }
}
