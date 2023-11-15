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

/// @title ERC20Airdrop2
/// Contract for managing Taiko token airdrop for eligible users but the
/// withdrawal is not immediate and is subject to a withdrawal window.
contract ERC20Airdrop2 is MerkleClaimable {
    address public token;
    address public vault;
    mapping(address => uint256) public claimedAmount;
    mapping(address => uint256) public withdrawnAmount;
    uint64 public withdrawalWindow;
    uint256[48] private __gap;

    function init(
        uint64 _claimStarts,
        uint64 _claimEnds,
        bytes32 _merkleRoot,
        address _token,
        address _vault,
        uint64 _withdrawalWindow
    )
        external
        initializer
    {
        MerkleClaimable._init();
        _setConfig(_claimStarts, _claimEnds, _merkleRoot);

        token = _token;
        vault = _vault;
        withdrawalWindow = _withdrawalWindow;
    }

    function withdraw(address user) external {
        (, uint256 amount) = getBalance(user);
        withdrawnAmount[user] += amount;
        IERC20Upgradeable(token).transferFrom(vault, user, amount);
    }

    function getBalance(address user)
        public
        view
        returns (uint256 balance, uint256 withdrawableAmount)
    {
        // TODO(dani):
    }

    function _claimWithData(bytes calldata data) internal override {
        (address user, uint256 amount) = abi.decode(data, (address, uint256));
        claimedAmount[user] += amount;
    }
}

/// @title ProxiedERC20Airdrop2
/// @notice Proxied version of the parent contract.
contract ProxiedERC20Airdrop2 is Proxied, ERC20Airdrop2 { }
