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

/**
 * This contract is for vaulting (and releasing) ERC721 tokens
 * @dev Only the contract owner can authorize or deauthorize addresses.
 * @custom:security-contact hello@taiko.xyz
 */
contract Erc721Vault is EssentialContract, NftBridgeErrors, IERC721ReceiverUpgradeable {
    using LibAddress for address;

    // Maps contract to a contract on a different chain
    struct ContractMapping {
        address sisterContract;
        string tokenName;
        string tokenSymbol;
        mapping (uint256 tokenId => bool inVault) tokenInVault;
    }
    mapping(address tokenContract => ContractMapping wrappedTokenContract) originalToWrapperData;

    mapping(address addr => bool isAuthorized) private _authorizedAddrs;
    uint256[49] private __gap;

    event Authorized(address indexed addr, bool authorized);
    event TokensReleased(address indexed to, address contractAddress, uint256[] tokenIds);

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
     * sender is authorized.
     * @param recipient Address to receive Ether.
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
     * Set the authorized status of an address, only the owner can call this.
     * @param addr Address to set the authorized status of.
     * @param authorized Authorized status to set.
     */
    function authorize(address addr, bool authorized) public onlyOwner {
        if (addr == address(0) || _authorizedAddrs[addr] == authorized) {
            revert ERC721_B_TV_PARAM();
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

    function onERC721Received(address, address, uint256, bytes calldata ) external pure returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }
}

contract ProxiedErc721Vault is Proxied, Erc721Vault { }
