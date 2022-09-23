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
import "../L1/TkoToken.sol";
import "./BridgedERC20.sol";
import "./IBridge.sol";
import "./ITokenVault.sol";

/**
 *  @dev This vault holds Ether.
 */
contract EtherVault is EssentialContract {

    mapping(address => bool) private authorizedAddrs;

    event Authorized(address indexed addr, bool authorized);

    modifier onlyAuthorized() {
        require(isAuthorized(msg.sender), "EV:denied");
        _;
    }

    receive() external payable {}

    function receiveEther(uint amount)
        public
        onlyAuthorized
        nonReentrant
    {
        msg.sender.sendEther(amount);
    }

    function authorize(address addr, bool authorized)
        public
        onlyOwner
    {
        require(
            addr!= address(0) && authorizedAddrs[addr] != authorized,
            "EV:param"
        );
        authorizedAddrs[addr] = authorized;
        emit Authorized(addr, authorized);
    }

    function isAuthorized(address addr) pubic view returns(bool) {
        return authorizedAddrs[addr];
    }
}
