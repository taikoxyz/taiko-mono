// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibAddress.sol";

/// @title TestDelegateOwned
/// @notice The contract serves as a playground for testing DelegateOwner on mainnet
/// @custom:security-contact security@taiko.xyz
contract TestDelegateOwned is EssentialContract {
    using SafeERC20 for IERC20;
    /// @notice Variable, changeable by the owner. By default this is the amount sent by the
    /// withdraw function. It is not necessarily "ether" per see. It can be any token but the amount
    /// denominated in ether.

    uint256 public etherAmount; // slot 1

    event EtherAmountChanged(uint256 oldValue, uint256 newValue);
    event TokenSent(address token, address to, uint256 amount);

    uint256[49] private __gap;

    constructor() EssentialContract() { }

    /// @param _owner Should be DelegateOwner so that L1 TaikoDAO can be in charge
    function init(address _owner) external initializer {
        __Essential_init(_owner);
        // By default, set it to 0.001 ETH
        etherAmount = 0.001 ether;
    }

    receive() external payable { }

    /// @notice Setting the etherAmount variable - only by the owner
    /// @param _etherAmount New ether amount to be sent
    function setEtherAmount(uint256 _etherAmount) external onlyOwner {
        emit EtherAmountChanged(etherAmount, _etherAmount);
        etherAmount = _etherAmount;
    }

    /// @notice Withdraw tokens or ether with the amount equivalent to etherAmount
    /// @param _token Token contract address or address(0) if ether
    /// @param _to The recipient address
    function withdraw(address _token, address _to) external onlyOwner nonReentrant {
        if (_token == address(0)) {
            LibAddress.sendEtherAndVerify(_to, etherAmount);
        } else {
            IERC20(_token).safeTransfer(_to, etherAmount);
        }

        emit TokenSent(_token, _to, etherAmount);
    }
}
