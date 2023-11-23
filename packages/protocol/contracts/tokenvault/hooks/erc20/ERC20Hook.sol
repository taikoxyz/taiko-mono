// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "../../../common/EssentialContract.sol";
import "./IERC20Hook.sol";

/// @title ERC20Hook
/// A hook that helps with custom erc20 bridging based on some standards (e.g.: circle's USDC).
contract ERC20Hook is EssentialContract, IERC20Hook {
    struct DeployedToCanoincalData {
        address canonicalAddress;
        uint8 burnFunctionSignature;
    }

    // This is needed for bridging native to CHAIN_X (_getOrDeployBridgedToken() on L2 if this is
    // the USDC)
    mapping(address => address) public canonicalToPredeployed;
    // This is needed for bridging native back to NATIVE_CHAIN (_handleMessage() on L2 if this is
    // the USDC)
    // In case burnFunctionSignature is NOT 0 -> It means it is a bridged, but native token.
    // If we need to add support for USDT and they have a different burn function signature, the
    // only thing needed is to update the IERC20Hook interface and adding a new if-else into the
    // ERC20Vault's _handleMessage()-
    mapping(address l2Address => DeployedToCanoincalData) public predeployedToCanonical;

    uint256[49] private __gap;

    event ERC20_CUSTOM_ADDED(address l1Address, address l2Counterpart);
    event ERC20_CUSTOM_DELETED(address l1Address, address l2Counterpart);

    error ERC20_HOOK_INVALID_ADDRESS();
    error ERC20_HOOK_INVALID_BURN_SIGNATURE_ID();

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Adds a custom, pre-deployed contract mapping to it's L1 (parent chain) counterpart
    /// @param l1Address The address of the token on L1 (or parent chain)
    /// @param deployedCounterpart The address on L2 - it can be address(0) in which case we delete
    /// the mappping (see explanation below).
    /// @param burnfunctionSigId The function signature id, indexed from 1, and 1 means the burn()
    /// in
    /// @param deleteCustom Indicates deleting both of the mappings
    function changeCustomToken(
        address l1Address,
        address deployedCounterpart,
        uint8 burnfunctionSigId,
        bool deleteCustom
    )
        external
        onlyOwner
    {
        if (l1Address == address(0) || deployedCounterpart == address(0)) {
            revert ERC20_HOOK_INVALID_ADDRESS();
        }

        if (deleteCustom) {
            delete canonicalToPredeployed[l1Address];
            delete predeployedToCanonical[deployedCounterpart];

            emit ERC20_CUSTOM_DELETED(l1Address, deployedCounterpart);
        } else {
            // Do not allow to have a 0 burn funciton signature, this way we can signal, that the
            // token is a 'custom token'.
            if (burnfunctionSigId == 0) revert ERC20_HOOK_INVALID_BURN_SIGNATURE_ID();

            canonicalToPredeployed[l1Address] = deployedCounterpart;
            predeployedToCanonical[deployedCounterpart] =
                DeployedToCanoincalData(l1Address, burnfunctionSigId);

            emit ERC20_CUSTOM_ADDED(l1Address, deployedCounterpart);
        }
    }

    /// @notice Queries the custom token if any.
    /// @param l1Address The address of the token on L1
    function getCustomCounterPart(address l1Address) external view returns (address) {
        return canonicalToPredeployed[l1Address];
    }

    function getCanonicalAndBurnSignature(address l2Address)
        external
        view
        returns (address, uint8)
    {
        return (
            predeployedToCanonical[l2Address].canonicalAddress,
            predeployedToCanonical[l2Address].burnFunctionSignature
        );
    }

    // Just define here the different burn functions we be supporting !
    // USDC's:
    function burn(uint256 amuont) external { }
}

/// @title ProxiedERC20Hook
/// @notice Proxied version of the parent contract.
contract ProxiedERC20Hook is Proxied, ERC20Hook { }
