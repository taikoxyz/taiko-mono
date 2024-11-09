// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";

contract EssentialContractStub is EssentialContract {
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }
}
