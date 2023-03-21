// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {
    ERC20Upgradeable,
    IERC20Upgradeable
} from "../thirdparty/ERC20Upgradeable.sol";
import {EssentialContract} from "../common/EssentialContract.sol";
import {IMintableERC20} from "../common/IMintableERC20.sol";
import {LibMath} from "../libs/LibMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

/// @dev This is Taiko's governance and fee token.
contract TaikoToken is EssentialContract, ERC20Upgradeable, IMintableERC20 {
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    /*********************
     * State Variables   *
     *********************/

    uint256[50] private __gap;

    /*********************
     * Events and Errors *
     *********************/
    event Mint(address account, uint256 amount);
    event Burn(address account, uint256 amount);

    error TKO_INVALID_ADDR();
    error TKO_INVALID_PREMINT_PARAMS();

    /*********************
     * External Functions*
     *********************/

    /// @dev Initializer to be called after being deployed behind a proxy.
    ///      Based on our simulation in simulate/tokenomics/index.js, both
    ///      amountMintToDAO and amountMintToDev shall be set to ~150,000,000.
    function init(
        address _addressManager,
        string calldata _name,
        string calldata _symbol,
        address[] calldata _premintRecipients,
        uint256[] calldata _premintAmounts
    ) external initializer {
        if (_premintRecipients.length != _premintAmounts.length)
            revert TKO_INVALID_PREMINT_PARAMS();

        EssentialContract._init(_addressManager);
        ERC20Upgradeable.__ERC20_init({
            name_: _name,
            symbol_: _symbol,
            decimals_: 18
        });

        for (uint i = 0; i < _premintRecipients.length; ++i) {
            _mint(_premintRecipients[i], _premintAmounts[i]);
        }
    }

    /*********************
     * Public Functions  *
     *********************/

    function transfer(
        address to,
        uint256 amount
    ) public override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        if (to == address(this)) revert TKO_INVALID_ADDR();
        return ERC20Upgradeable.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        if (to == address(this)) revert TKO_INVALID_ADDR();
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    /**
     * @dev Mints tokens to the given address's balance. This will increase
     *      the circulating supply.
     * @param account The address to receive the tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(
        address account,
        uint256 amount
    ) public onlyFromNamed("proto_broker") {
        if (account == address(0)) revert TKO_INVALID_ADDR();
        _mint(account, amount);
        emit Mint(account, amount);
    }

    /**
     * @dev Burn tokens from the given address's balance. This will decrease
     *      the circulating supply.
     * @param account The address to burn the tokens from.
     * @param amount The amount of tokens to burn.
     */
    function burn(
        address account,
        uint256 amount
    ) public onlyFromNamed("proto_broker") {
        if (account == address(0)) revert TKO_INVALID_ADDR();
        _burn(account, amount);
        emit Burn(account, amount);
    }
}
