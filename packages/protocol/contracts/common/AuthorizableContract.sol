pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";

/// @title AuthorizableContract
abstract contract AuthorizableContract is EssentialContract {
    mapping(address => bytes32 label) public authorizedAddresses;
    uint256[49] private __gap;

    event Authorized(address indexed addr, bytes32 oldLabel, bytes32 newLabel);

    error ADDRESS_NOT_AUTHORIZED();
    error ADDRESS_INVALID();

    modifier onlyAuthorized() {
        // Ensure the caller is authorized to perform the action
        if (!isAuthorized(msg.sender)) revert ADDRESS_NOT_AUTHORIZED();
        _;
    }

    modifier onlyAuthorizedAs(bytes32 label) {
        // Ensure the caller is authorized to perform the action
        if (!isAuthorizedAs(msg.sender, label)) revert ADDRESS_NOT_AUTHORIZED();
        _;
    }

    function authorize(address addr, bytes32 label) external onlyOwner {
        if (addr == address(0)) revert ADDRESS_INVALID();

        bytes32 oldLabel = authorizedAddresses[addr];
        authorizedAddresses[addr] = label;

        emit Authorized(addr, oldLabel, label);
    }

    function isAuthorized(address addr) public view returns (bool) {
        return addr != address(0) && authorizedAddresses[addr] != 0;
    }

    function isAuthorizedAs(
        address addr,
        bytes32 label
    )
        public
        view
        returns (bool)
    {
        return addr != address(0) && label != 0
            && authorizedAddresses[addr] == label;
    }

    /// @dev Initialization method for setting up AddressManager reference.
    /// @param _addressManager Address of the AddressManager.
    function _init(address _addressManager) internal virtual override {
        EssentialContract._init(_addressManager);
    }
}
