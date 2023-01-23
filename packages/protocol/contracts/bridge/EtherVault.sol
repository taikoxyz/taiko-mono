// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

// solhint-disable-next-line max-line-length
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";

import "../common/EssentialContract.sol";
import "../libs/LibAddress.sol";

/**
 * Vault that holds Ether.
 * @author dantaik <dan@taiko.xyz>
 */
contract EtherVault is EssentialContract {
    using LibAddress for address;

    /*********************
     * State Variables   *
     *********************/

    mapping(address => bool) private authorizedAddrs;
    uint256[49] private __gap;

    /*********************
     * Events            *
     *********************/

    event Authorized(address indexed addr, bool authorized);

    event EtherTransferred(address indexed to, uint256 amount);

    /*********************
     * Modifiers         *
     *********************/

    modifier onlyAuthorized() {
        require(isAuthorized(msg.sender), "EV:denied");
        _;
    }

    /*********************
     * External Functions*
     *********************/

    receive() external payable {
        // EthVault's balance must == 0 OR the sender isAuthorized.
        require(
            address(this).balance == 0 || isAuthorized(msg.sender),
            "EV:denied"
        );
    }

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /*********************
     * Public Functions  *
     *********************/

    /**
     * Transfer Ether from EtherVault to the sender, checking they are authorized.
     * @param amount Amount of ether to send.
     */
    function receiveEther(uint256 amount) public onlyAuthorized nonReentrant {
        msg.sender.sendEther(amount);
        emit EtherTransferred(msg.sender, amount);
    }

    /**
     * Transfer Ether from EtherVault to the sender, checking they are authorized.
     * @param recipient Address to receive Ether
     * @param amount Amount of ether to send.
     */
    function receiveEther(
        address recipient,
        uint256 amount
    ) public onlyAuthorized nonReentrant {
        require(recipient != address(0), "EV:recipient");
        recipient.sendEther(amount);
        emit EtherTransferred(recipient, amount);
    }

    /**
     * Set the authorized status of an address, only the owner can call this.
     * @param addr Address to set the authorized status of.
     * @param authorized Authorized status to set.
     */
    function authorize(address addr, bool authorized) public onlyOwner {
        require(
            addr != address(0) && authorizedAddrs[addr] != authorized,
            "EV:param"
        );
        authorizedAddrs[addr] = authorized;
        emit Authorized(addr, authorized);
    }

    /**
     * Get the authorized status of an address.
     * @param addr Address to get the authorized status of.
     */
    function isAuthorized(address addr) public view returns (bool) {
        return authorizedAddrs[addr];
    }
}
