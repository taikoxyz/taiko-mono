// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract RegisterGalxePoints {
    mapping(address => bool) public alreadyRegistered;

    event Registered(address registrant);

    function register() public {
        require(!alreadyRegistered[msg.sender], "Address already registered");
        alreadyRegistered[msg.sender] = true;
        emit Registered(msg.sender);
    }
}
