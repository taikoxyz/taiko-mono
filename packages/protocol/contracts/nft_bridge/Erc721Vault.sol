// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC721ReceiverUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import { IERC721Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { LibAddress } from "../libs/LibAddress.sol";
import { NftBridgeErrors } from "./NftBridgeErrors.sol";
import { SisterContract } from "./erc721/SisterContract.sol";

/**
 * This contract is for vaulting (and releasing) ERC721 tokens
 * @dev Only the contract owner can authorize or deauthorize addresses.
 * @custom:security-contact hello@taiko.xyz
 */
contract Erc721Vault is EssentialContract, NftBridgeErrors, IERC721ReceiverUpgradeable {
    using LibAddress for address;

    // Maps contract to a contract on a different chain
    struct ContractMapping {
        address sisterContractAddress;
        string tokenName;
        string tokenSymbol;
        mapping (uint256 tokenId => bool inVault) tokenInVault;
    }
    // This holds the original to wrapped and additional data
    mapping(address tokenContract => ContractMapping wrappedTokenContract) originalToWrappedCollection;
    // This holds the mapping for bridging back to original chain
    mapping(address wrappedTokenContract => address originalTokenContract) wrappedToOriginal;
    // This holds if a native on this chain or not
    mapping(address tokenContract => bool isNative) isNativeCollection;

    mapping(address addr => bool isAuthorized) private _authorizedAddrs;
    uint256[49] private __gap;

    event Authorized(address indexed addr, bool authorized);
    event TokensReleased(address indexed to, address contractAddress, uint256[] tokenIds);
    event TokensReleasedAndOrMinted(address indexed to, address contractAddress, uint256[] tokenIds);

    modifier onlyAuthorized() {
        if (!isAuthorized(msg.sender)) {
            revert ERC721_TV_NOT_AUTHORIZED();
        }
        _;
    }

    /**
     * Initialize the contract with an address manager
     * @param addressManager The address of the address manager
     */
    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /**
     * Transfer token(s) from Erc721Vault to a designated address, checking that the
     * sender is authorized. This function is called when we need to send back tokens
     * to owner due to failed messgae status on destination chain.
     * @param recipient Address to receive tokens.
     * @param tokenContract Token contract.
     * @param tokenIds Array of tokenIds to be sent
     */
    function releaseTokens(
        address recipient,
        address tokenContract,
        uint256[] memory tokenIds
    )
        public
        onlyAuthorized
        nonReentrant
    {
        if (recipient == address(0)) {
            revert ERC721_TV_DO_NOT_BURN();
        }

        for (uint256 i; i < tokenIds.length; i++) {
            IERC721Upgradeable(tokenContract).safeTransferFrom(address(this), recipient, tokenIds[i]);
        }

        emit TokensReleased(recipient, tokenContract, tokenIds);
    }

    /**
     * Transfer token(s) from Erc721Vault to a designated address, checking that the
     * sender is authorized. This is called during bridging (!). This is called from processMessage()
     * so always on the 'other side' of the chain where was initiated.
     * @param recipient Address to receive tokens
     * @param tokenContract Token contract
     * @param tokenIds Array of tokenIds to be sent
     * @param tokenURIs Array of tokenURIs
     * @param tokenName Name of the token
     * @param tokenSymbol Token symbol
     */
    function releaseOrMintTokens(
        address recipient,
        address tokenContract,
        uint256[] memory tokenIds,
        string[] memory tokenURIs,
        string memory tokenName,
        string memory tokenSymbol
    )
        public
        onlyAuthorized
        nonReentrant
    {
        if (recipient == address(0)) {
            revert ERC721_TV_DO_NOT_BURN();
        }

        // First we need to check if NOT NATIVE chain token
        if (!isNativeCollection[tokenContract]) {
            // 1. If originalToWrappedCollection[tokenContract].sisterContract == address(0)
            // Then we can say:
            // - This collection is non native and requires a new contract
            if(originalToWrappedCollection[tokenContract].sisterContractAddress == address(0)) {
                address freshlyDeployedContract = address(new SisterContract(tokenName, tokenSymbol));
                originalToWrappedCollection[tokenContract].sisterContractAddress = freshlyDeployedContract;
                wrappedToOriginal[freshlyDeployedContract] = tokenContract;
            }

            // 2. Anyways, we need to either MINT or TRANSFER from this vault
            // If there is no contract yet, then deploy a wrapped one
            for (uint256 i; i < tokenIds.length; i++) {
                    SisterContract(originalToWrappedCollection[tokenContract].sisterContractAddress)
                    .safeMintOrTransfer(recipient, tokenIds[i], tokenURIs[i]);
            }
        }
        else {
            // These tokens are already available here to be transferred out
            for (uint256 i; i < tokenIds.length; i++) {
                IERC721Upgradeable(tokenContract).safeTransferFrom(
                 address(this), recipient, tokenIds[i]);
            }
        }

        emit TokensReleasedAndOrMinted(recipient, tokenContract, tokenIds);
    }

    /**
     * Called when sendMessage is called and sets if contract is native or not.
     * @param tokenContract Token contract address
     */
    function setNative(
        address tokenContract
    )
        public
        onlyAuthorized
        nonReentrant
    {
        isNativeCollection[tokenContract] = true;
    }

    /**
     * Set the authorized status of an address, only the owner can call this.
     * @param addr Address to set the authorized status of.
     * @param authorized Authorized status to set.
     */
    function authorize(address addr, bool authorized) public onlyOwner {
        if (addr == address(0) || _authorizedAddrs[addr] == authorized) {
            revert ERC721_TV_PARAM();
        }
        _authorizedAddrs[addr] = authorized;
        emit Authorized(addr, authorized);
    }

    /**
     * Get the authorized status of an address.
     * @param addr Address to get the authorized status of.
     */
    function isAuthorized(address addr) public view returns (bool) {
        return _authorizedAddrs[addr];
    }

    /**
     * If the asset during bridging has a counterpart in the wrappedToOriginal then we need to use it
     * as original contract address - so that we get back our original assets on the original chain.
     * @param tokenContract Address to check if the token in query is a wrap or original
     */
    function getOriginalContractAddress(address tokenContract) public view returns (address) {
        return wrappedToOriginal[tokenContract];
    }

    function onERC721Received(address, address, uint256, bytes calldata ) external pure returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }
}

contract ProxiedErc721Vault is Proxied, Erc721Vault { }
