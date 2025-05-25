// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibAddress.sol";

/// @title FooUpgradeable
/// @custom:security-contact security@taiko.xyz
contract FooUpgradeable is EssentialContract {
    using SafeERC20 for IERC20;

    event TokenSent(address token, address to, uint256 amount);

    uint256[50] private __gap;

    receive() external payable { }

    constructor() EssentialContract() { }

    /// @param _owner Should be DAOController so that L1 TaikoDAO can be in charge
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Withdraw tokens or ether with the amount equivalent to etherAmount
    /// @param _token Token contract address or address(0) if ether
    /// @param _to The recipient address
    /// @param _amount The amount to withdraw
    function withdraw(
        address _token,
        address _to,
        uint256 _amount
    )
        external
        onlyOwner
        nonReentrant
    {
        if (_token == address(0)) {
            LibAddress.sendEtherAndVerify(_to, _amount);
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }

        emit TokenSent(_token, _to, _amount);
    }
}
