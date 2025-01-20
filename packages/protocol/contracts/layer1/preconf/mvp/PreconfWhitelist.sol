// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";

contract PreconfWhitelist is EssentialContract {
    address[] private whitelist;

    mapping(address proposer => bool whitelisted) private isWhitelisted;

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function eligibleProposer(address _proposer) external view returns (bool) {
        return isWhitelisted[_proposer];
    }

    function registerProposer(address _proposer) external onlyOwner {
        require(!isWhitelisted[_proposer], "Address is already whitelisted");
        whitelist.push(_proposer);
        isWhitelisted[_proposer] = true;
    }

    function deregisterProposer(address _proposer) external onlyOwner {
        require(isWhitelisted[_proposer], "Address is not whitelisted");

        for (uint256 i = 0; i < whitelist.length; i++) {
            if (whitelist[i] == _proposer) {
                whitelist[i] = whitelist[whitelist.length - 1];
                whitelist.pop();
                break;
            }
        }

        isWhitelisted[_proposer] = false;
    }

    function getWhitelist() external view returns (address[] memory) {
        return whitelist;
    }
}
