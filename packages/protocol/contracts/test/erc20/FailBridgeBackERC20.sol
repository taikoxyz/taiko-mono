// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice An ERC20 token for creating a 'failed' status (testing only!)
/// @dev Need to create failed messages on the destination chain, and
/// @dev by getting a storage proof (eth_getProof) of the message
/// @dev (that it failed) so that can perform some actions.
contract FailWhenBridgeBackCanonical is ERC20 {
    mapping(address minter => bool hasMinted) public minters;

    error HasMinted();

    constructor(string memory name, string memory symbol) ERC20(name, symbol) { }

    /**
     * Public, open mint function
     * @dev It is a one-time mint function / address
     * @param to The address to mint to
     */
    function mint(address to) public {
        if (minters[msg.sender]) {
            revert HasMinted();
        }

        minters[msg.sender] = true;
        _mint(to, 50 * (10 ** decimals()));
    }

    /**
     * transfer() function to fail when Bridge calls it.
     * @dev This will create failed when bridges tries to
     * recall it
     */
    function transfer(
        address,
        uint256
    )
        public
        virtual
        override
        returns (bool)
    {
        revert("Cannot bridge back to canonical.");
    }
}
