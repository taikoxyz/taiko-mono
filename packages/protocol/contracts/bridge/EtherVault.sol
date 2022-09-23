// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";

import "../common/EssentialContract.sol";
import "../libs/LibAddress.sol";

/// @dev This vault holds Ether.
/// @author dantaik <dan@taiko.xyz>
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

    receive() external payable onlyAuthorized {}

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /*********************
     * Public Functions  *
     *********************/

    function receiveEther(uint256 amount) public onlyAuthorized nonReentrant {
        msg.sender.sendEther(amount);
    }

    function authorize(address addr, bool authorized) public onlyOwner {
        require(
            addr != address(0) && authorizedAddrs[addr] != authorized,
            "EV:param"
        );
        authorizedAddrs[addr] = authorized;
        emit Authorized(addr, authorized);
    }

    function isAuthorized(address addr) public view returns (bool) {
        return authorizedAddrs[addr];
    }
}
