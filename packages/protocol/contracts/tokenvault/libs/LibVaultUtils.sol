// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TransparentUpgradeableProxy } from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IBridge } from "../../bridge/IBridge.sol";

library LibVaultUtils {
    uint256 public constant MAX_TOKEN_PER_TXN = 10;

    error VAULT_INVALID_FROM();
    error VAULT_INVALID_IMPL();
    error VAULT_INVALID_TOKEN();
    error VAULT_INVALID_TO();
    error VAULT_TOKEN_ARRAY_MISMATCH();
    error VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();
    error VAULT_INVALID_AMOUNT();

    /// @dev Deploys a contract (via proxy)
    /// @param implementation The new implementation address
    /// @param owner The owner of the proxy admin contract
    /// @param initializationData Data for the initialization
    function deployProxy(
        address implementation,
        address owner,
        bytes memory initializationData
    )
        external
        returns (address proxy)
    {
        if (implementation == address(0)) revert VAULT_INVALID_IMPL();
        proxy = address(
            new TransparentUpgradeableProxy(implementation, owner, initializationData)
        );
    }

    /// @dev Checks if context is valid
    /// @param validSender The valid sender to be allowed
    /// @param resolver The address of the resolver
    function checkValidContext(
        bytes32 validSender,
        address resolver
    )
        external
        view
        returns (IBridge.Context memory ctx)
    {
        ctx = IBridge(msg.sender).context();
        address sender = AddressResolver(resolver).resolve(
            ctx.srcChainId, validSender, false
        );
        if (ctx.from != sender) revert VAULT_INVALID_FROM();
    }

    function checkIfValidAddresses(
        address vault,
        address to,
        address token
    )
        external
        pure
    {
        if (to == address(0) || to == vault) revert VAULT_INVALID_TO();
        if (token == address(0)) revert VAULT_INVALID_TOKEN();
    }

    function checkIfValidAmounts(
        uint256[] memory amounts,
        uint256[] memory tokenIds,
        bool isERC721
    )
        external
        pure
    {
        if (tokenIds.length != amounts.length) {
            revert VAULT_TOKEN_ARRAY_MISMATCH();
        }

        if (tokenIds.length > MAX_TOKEN_PER_TXN) {
            revert VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();
        }

        if (isERC721) {
            for (uint256 i; i < tokenIds.length; ++i) {
                if (amounts[i] != 0) revert VAULT_INVALID_AMOUNT();
            }
        } else {
            for (uint256 i; i < amounts.length; ++i) {
                if (amounts[i] == 0) revert VAULT_INVALID_AMOUNT();
            }
        }
    }
}
