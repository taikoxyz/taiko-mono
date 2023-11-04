// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { Proxied } from "../../common/Proxied.sol";

import { MerkleClaimable } from "./MerkleClaimable.sol";

/// @title ERC20Airdrop
/// Contract for managing Taiko token airdrop for eligible users
contract ERC20Airdrop is MerkleClaimable {
    address public token;
    address public vault;

    function init(
        bytes32 _merkleRoot,
        address _token,
        address _vault
    )
        external
        initializer
    {
        MerkleClaimable._init(_merkleRoot);
        token = _token;
        vault = _vault;
    }

    function claimWithData(bytes calldata data) internal override {
        (address user, uint256 amount) = abi.decode(data, (address, uint256));
        IERC20Upgradeable(token).transferFrom(vault, user, amount);
    }
}

/// @title ProxiedERC20Airdrop
/// @notice Proxied version of the parent contract.
contract ProxiedERC20Airdrop is Proxied, ERC20Airdrop { }
