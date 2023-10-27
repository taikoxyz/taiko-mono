// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";

/// @title AuthorizableContract
/// @notice Every contract which needs to have authorization (EtherVault,
/// ERCXXVault)
contract AuthorizableContract is EssentialContract {
    // Authorized addresses
    mapping(address addr => bool authorized) public isAuthorized;

    uint256[49] private __gap;

    event Authorized(address indexed addr, bool authorized);

    error VAULT_PERMISSION_DENIED();
    error VAULT_INVALID_PARAMS();

    modifier onlyAuthorized() {
        // Ensure the caller is authorized to perform the action
        if (!isAuthorized[msg.sender]) revert VAULT_PERMISSION_DENIED();
        _;
    }
    /// @notice Initializes the contract with an address manager.
    /// @param addressManager The address of the address manager.

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    function authorize(address addr, bool authorized) public onlyOwner {
        if (addr == address(0)) revert VAULT_INVALID_PARAMS();
        if (isAuthorized[addr] == authorized) revert VAULT_INVALID_PARAMS();

        isAuthorized[addr] = authorized;
        emit Authorized(addr, authorized);
    }
}
