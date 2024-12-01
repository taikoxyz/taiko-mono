// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibAddress.sol";
import "../CommonTest.sol";

// TODO: delete or better name these contracts?
contract CalldataReceiver {
    // Returns success
    function returnSuccess() public pure returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool result) {
        if (interfaceId == 0x10101010) {
            result = true;
        }
    }

    // Reverts
    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }
}

/// @notice The reason we call LibAddress.sendEther this way is - and not directly inside of a
/// test_sendEther() because this way the coverage adds up if you call functions against initiated
/// contracts, so basically it is a workaround making the library test 'count' towards the coverage.
/// @dev The EtherSenderContract in live environment is the Bridge.
contract EtherSenderContract {
    function sendEther(
        address _to,
        uint256 _amount,
        uint256 _gasLimit,
        bytes memory _calldata
    )
        public
        returns (bool success_)
    {
        success_ = LibAddress.sendEther(_to, _amount, _gasLimit, _calldata);
    }

    function sendEtherAndVerify(address _to, uint256 _amount, uint256 _gasLimit) public {
        LibAddress.sendEtherAndVerify(_to, _amount, _gasLimit);
    }

    function sendEtherAndVerify(address _to, uint256 _amount) public {
        LibAddress.sendEtherAndVerify(_to, _amount);
    }

    function supportsInterface(
        address _addr,
        bytes4 _interfaceId
    )
        public
        view
        returns (bool result)
    {
        return LibAddress.supportsInterface(_addr, _interfaceId);
    }
}
