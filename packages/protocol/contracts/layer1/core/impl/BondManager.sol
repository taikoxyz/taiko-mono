// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBondManager } from "../iface/IBondManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

import "./BondManager_Layout.sol"; // DO NOT DELETE

/// @title BondManager
/// @notice L1 bond manager handling deposits/withdrawals and liveness slashing.
/// @custom:security-contact security@taiko.xyz
contract BondManager is EssentialContract, IBondManager {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Address allowed to call debitBond, creditBond, and processLivenessBond.
    address public immutable bondOperator;

    /// @notice ERC20 token used as bond.
    IERC20 public immutable bondToken;

    /// @notice Bond amount (Wei) for liveness guarantees.
    uint256 public immutable livenessBond;

    /// @notice Per-account bond balance.
    mapping(address account => uint256 balance) public bondBalance;

    uint256[44] private __gap;

    // ---------------------------------------------------------------
    // Constructor and Initialization
    // ---------------------------------------------------------------

    /// @notice Constructor disables initializers for upgradeable pattern.
    /// @param _bondToken The ERC20 bond token address.
    /// @param _bondOperator Address allowed to debit/credit bonds.
    /// @param _livenessBond Liveness bond amount (Wei).
    constructor(
        address _bondToken,
        address _bondOperator,
        uint256 _livenessBond
    ) {
        require(_bondToken != address(0), InvalidAddress());
        require(_bondOperator != address(0), InvalidAddress());

        bondToken = IERC20(_bondToken);
        bondOperator = _bondOperator;
        livenessBond = _livenessBond;
    }

    /// @notice Initializes the BondManager contract.
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IBondManager
    function debitBond(address _address, uint256 _bond) external onlyFrom(bondOperator) {
        _debitBond(_address, _bond);
    }

    /// @inheritdoc IBondManager
    function creditBond(address _address, uint256 _bond) external onlyFrom(bondOperator) {
        _creditBond(_address, _bond);
    }

    /// @inheritdoc IBondManager
    function deposit(uint256 _amount) external nonReentrant {
        _deposit(msg.sender, msg.sender, _amount);
    }

    /// @inheritdoc IBondManager
    function depositTo(address _recipient, uint256 _amount) external nonReentrant {
        require(_recipient != address(0), InvalidAddress());
        _deposit(msg.sender, _recipient, _amount);
    }

    /// @inheritdoc IBondManager
    function withdraw(address _to, uint256 _amount) external nonReentrant {
        _withdraw(msg.sender, _to, _amount);
    }

    /// @inheritdoc IBondManager
    function processLivenessBond(
        address _payer,
        address _payee,
        address _caller
    )
        external
        onlyFrom(bondOperator)
        nonReentrant
        returns (uint256 debitedAmount_)
    {
        uint256 debited = livenessBond;
        if (debited == 0) {
            emit LivenessBondProcessed(_payer, _payee, _caller, 0, 0, 0);
            return 0;
        }

        uint256 payeeAmount;
        uint256 callerAmount;

        if (_payer == _payee) {
            payeeAmount = (debited * 4) / 10; // 40%
            callerAmount = debited / 10; // 10%

            if (payeeAmount > 0) _creditBond(_payee, payeeAmount);
            if (callerAmount > 0) _creditBond(_caller, callerAmount);
        } else {
            payeeAmount = debited / 2; // 50% (rounds down, favors burn on odd amounts)
            if (payeeAmount > 0) _creditBond(_payee, payeeAmount);
        }

        emit LivenessBondProcessed(_payer, _payee, _caller, debited, payeeAmount, callerAmount);
        return debited;
    }

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IBondManager
    function getBondBalance(address _address) external view returns (uint256) {
        return _getBondBalance(_address);
    }

    /// @inheritdoc IBondManager
    function hasSufficientBond(
        address _address,
        uint256 _additionalBond
    )
        external
        view
        returns (bool)
    {
        return bondBalance[_address] >= livenessBond + _additionalBond;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Internal implementation for depositing bonds.
    /// @param _depositor The address providing the tokens.
    /// @param _recipient The address receiving the bond credit.
    /// @param _amount The amount to deposit.
    function _deposit(address _depositor, address _recipient, uint256 _amount) internal {
        bondToken.safeTransferFrom(_depositor, address(this), _amount);
        _creditBond(_recipient, _amount);
        emit BondDeposited(_depositor, _recipient, _amount);
    }

    /// @dev Internal implementation for debiting a bond.
    /// @param _address The address to debit the bond from.
    /// @param _bond The amount of bond to debit in gwei.
    function _debitBond(address _address, uint256 _bond) internal {
        if (_bond == 0) return;

        uint256 balance = bondBalance[_address];
        require(balance >= _bond, InsufficientBondBalance());
        unchecked {
            bondBalance[_address] = balance - _bond;
        }

        emit BondDebited(_address, _bond);
    }

    /// @dev Internal implementation for crediting a bond.
    /// @param _address The address to credit the bond to.
    /// @param _bond The amount of bond to credit in gwei.
    function _creditBond(address _address, uint256 _bond) internal {
        bondBalance[_address] = bondBalance[_address] + _bond;
        emit BondCredited(_address, _bond);
    }

    /// @dev Internal implementation for withdrawing funds from a user's bond balance.
    /// @param _from The address whose balance will be reduced.
    /// @param _to The recipient address.
    /// @param _amount The amount to withdraw.
    function _withdraw(address _from, address _to, uint256 _amount) internal {
        _debitBond(_from, _amount);
        bondToken.safeTransfer(_to, _amount);
        emit BondWithdrawn(_from, _amount);
    }

    /// @dev Internal implementation for getting the bond balance.
    /// @param _address The address to get the bond balance for.
    /// @return The bond balance of the address.
    function _getBondBalance(address _address) internal view returns (uint256) {
        return bondBalance[_address];
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidAddress();
    error InsufficientBondBalance();
}
