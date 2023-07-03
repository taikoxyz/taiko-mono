// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {
    IERC20Upgradeable,
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {EssentialContract} from "../common/EssentialContract.sol";
import {Proxied} from "../common/Proxied.sol";
import {BridgeErrors} from "./BridgeErrors.sol";

/// @custom:security-contact hello@taiko.xyz
contract BridgedERC20 is
    EssentialContract,
    IERC20Upgradeable,
    IERC20MetadataUpgradeable,
    ERC20Upgradeable,
    BridgeErrors
{
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public srcToken;
    uint256 public srcChainId;
    uint8 private srcDecimals;
    uint256[47] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event BridgeMint(address indexed account, uint256 amount);
    event BridgeBurn(address indexed account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                         USER-FACING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Initializer to be called after being deployed behind a proxy.
    // Intention is for a different BridgedERC20 Contract to be deployed
    // per unique _srcToken i.e. one for USDC, one for USDT etc.
    function init(
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        uint8 _decimals,
        string memory _symbol,
        string memory _name
    ) external initializer {
        if (
            _srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid
                || bytes(_symbol).length == 0 || bytes(_name).length == 0
        ) {
            revert B_INIT_PARAM_ERROR();
        }
        EssentialContract._init(_addressManager);
        ERC20Upgradeable.__ERC20_init({name_: _name, symbol_: _symbol});
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        srcDecimals = _decimals;
    }

    /// @dev only a TokenVault can call this function
    function bridgeMintTo(address account, uint256 amount) public onlyFromNamed("token_vault") {
        _mint(account, amount);
        emit BridgeMint(account, amount);
    }

    /// @dev only a TokenVault can call this function
    function bridgeBurnFrom(address account, uint256 amount) public onlyFromNamed("token_vault") {
        _burn(account, amount);
        emit BridgeBurn(account, amount);
    }

    /// @dev any address can call this
    // caller must have at least amount to call this
    function transfer(address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (to == address(this)) {
            revert B_ERC20_CANNOT_RECEIVE();
        }
        return ERC20Upgradeable.transfer(to, amount);
    }

    /// @dev any address can call this
    // caller must have allowance of at least 'amount'
    // for 'from's tokens.
    function transferFrom(address from, address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (to == address(this)) {
            revert B_ERC20_CANNOT_RECEIVE();
        }
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    function decimals()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (uint8)
    {
        return srcDecimals;
    }

    /// @dev returns the srcToken being bridged and the srcChainId
    // of the tokens being bridged
    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }
}

contract ProxiedBridgedERC20 is Proxied, BridgedERC20 {}
