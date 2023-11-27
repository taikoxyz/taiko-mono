// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "../../../common/EssentialContract.sol";
import "./IERC20NativeRegistry.sol";
import "../adapters/BaseAdapter.sol";
import "../../../libs/LibDeploy.sol";

interface IRemoveMapping {
    function resetCanonicalToBridged(uint256 chainId, address canonicalAddrToReset) external;
}

/// @title ERC20NativeRegistry
/// A registry that helps with custom erc20 bridging based on some standards (e.g.: circle's USDC).
/// It keeps track of mapping between native and counterpart contracts.
contract ERC20NativeRegistry is EssentialContract, IERC20NativeRegistry {
    struct PredeployedToCanonicalData {
        address canonicalERC20;
        address adapterAddress;
    }

    // This is needed for bridging native to CHAIN_X (_getOrDeployBridgedToken() on L2 if this is
    // the USDC)
    mapping(address => address) public canonicalToPredeployed;
    // This is needed for bridging native back to NATIVE_CHAIN (_handleMessage() on L2 if this is
    // the USDC)
    mapping(address l2Address => PredeployedToCanonicalData) public predeployedToCanonical;

    uint256[48] private __gap;

    event Erc20CustomAdded(address l1Address, address l2Counterpart);
    event Erc20CustomDeleted(address l1Address, address l2Counterpart);

    error ERC20_HOOK_INVALID_ADDRESS();
    error ERC20_HOOK_INVALID_BURN_SIGNATURE_ID();

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Adds a custom, pre-deployed contract mapping to it's L1 (parent chain) counterpart
    /// @param l1Address The address of the token on L1 (or parent chain)
    /// @param deployedCounterpart The address on L2 - it can be address(0) in which case we delete
    /// the mappping (see explanation below).
    /// @param adapterName The name based on which the adapter is queriable via the
    /// AddressManager
    /// @param deleteCustom Indicates deleting both of the mappings
    /// @param chainId ChainId the canonical originates from
    function changeCustomToken(
        address l1Address,
        address deployedCounterpart,
        bytes32 adapterName,
        uint64 chainId,
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

            // Need to erase the mapping in ERC20Vault too - in order to continue the support for
            // bridging from L1 to L2 - when for example Circle revokes minter role from our
            // adapter.
            IRemoveMapping(resolve(uint64(block.chainid), "erc20_vault", false))
                .resetCanonicalToBridged(chainId, l1Address);

            emit Erc20CustomDeleted(l1Address, deployedCounterpart);
        } else {
            canonicalToPredeployed[l1Address] = deployedCounterpart;

            predeployedToCanonical[deployedCounterpart] =
                PredeployedToCanonicalData(l1Address, resolve(adapterName, false));

            emit Erc20CustomAdded(l1Address, deployedCounterpart);
        }
    }

    /// @notice Queries the custom, predeployed token and it's adapter (if any).
    /// @param l1Address The address of the token on L1
    function getPredeployedAndAdapter(address l1Address) external view returns (address, address) {
        address preDeployed = canonicalToPredeployed[l1Address];
        return (preDeployed, predeployedToCanonical[preDeployed].adapterAddress);
    }

    /// @notice Gets the canonical token and the L2 adapter based on the given L2 address
    /// @param l2Address The address of the token on L1
    function getCanonicalAndAdapter(address l2Address) external view returns (address, address) {
        return (
            predeployedToCanonical[l2Address].canonicalERC20,
            predeployedToCanonical[l2Address].adapterAddress
        );
    }
}

/// @title ProxiedERC20NativeRegistry
/// @notice Proxied version of the parent contract.
contract ProxiedERC20NativeRegistry is Proxied, ERC20NativeRegistry { }
