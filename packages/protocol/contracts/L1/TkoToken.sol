// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../common/EssentialContract.sol";
import "../common/IMintableERC20.sol";
import "../libs/LibMath.sol";
import "../thirdparty/ERC20Upgradeable.sol";

/// @author dantaik <dan@taiko.xyz>
/// @dev This is Taiko's governance and fee token.
contract TkoToken is EssentialContract, ERC20Upgradeable, IMintableERC20 {
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    /*********************
     * State Variables   *
     *********************/

    uint256[50] private __gap;

    /*********************
     * Events            *
     *********************/
    event Mint(address account, uint256 amount);
    event Burn(address account, uint256 amount);

    /*********************
     * External Functions*
     *********************/

    /// @dev Initializer to be called after being deployed behind a proxy.
    ///      Based on our simulation in simulate/tokenomics/index.js, both
    ///      amountMintToDAO and amountMintToDev shall be set to ~150,000,000.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
        ERC20Upgradeable.__ERC20_init({
            name_: "Taiko Token",
            symbol_: "TKO",
            decimals_: 18
        });
    }

    /*********************
     * Public Functions  *
     *********************/

    function transfer(
        address to,
        uint256 amount
    ) public override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        require(to != address(this), "TKO: invalid to");
        return ERC20Upgradeable.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        require(to != address(this), "TKO: invalid to");
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
        require(account != address(0), "TKO: invalid address");
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
        require(account != address(0), "TKO: invalid address");
        _burn(account, amount);
        emit Burn(account, amount);
    }
}
