// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../common/EssentialContract.sol";
import "../common/IMintableERC20.sol";
import "../libs/LibMath.sol";
import "../thirdparty/ERC20Upgradeable.sol";

/// @author dantaik <dan@taiko.xyz>
/// @dev This is Taiko's governance token.
contract TaiToken is EssentialContract, ERC20Upgradeable, IMintableERC20 {
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    /*********************
     * State Variables   *
     *********************/

    uint256[50] private __gap;

    /*********************
     * Events            *
     *********************/
    event Burn(address account, uint256 amount, bool fromStaking);
    event Mint(address account, uint256 amount, bool toStaking);

    /*********************
     * External Functions*
     *********************/

    /// @dev Initializer to be called after being deployed behind a proxy.
    ///      Based on our simulation in simulate/tokenomics/index.js, both
    ///      amountMintToDAO and amountMintToDev shall be set to ~150,000,000.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
        ERC20Upgradeable.__ERC20_init("Taiko Token", "TAI", 18);
    }

    /*********************
     * Public Functions  *
     *********************/

    function transfer(address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        require(to != address(this), "TAI: invalid to");
        return ERC20Upgradeable.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        require(to != address(this), "TAI: invalid to");
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    /**
     * @dev Mints tokens to the given address's balance. This will increase
     *      the circulating supply.
     * @param account The address to receive the tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address account, uint256 amount)
        public
        onlyFromNamed("taiko_l1")
    {
        _mint(account, amount);
        emit Mint(account, amount, false);
    }
}
