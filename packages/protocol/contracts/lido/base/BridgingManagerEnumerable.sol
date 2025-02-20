// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.24;

import {EssentialContract} from "../../shared/common/EssentialContract.sol";

/// @author psirex
/// @notice Contains administrative methods to retrieve and control the state of the bridging
abstract contract BridgingManagerEnumerable is  EssentialContract {
    /// @dev Stores the state of the bridging
    /// @param isInitialized Shows whether the contract is initialized or not
    /// @param isDepositsEnabled Stores the state of the deposits
    /// @param isWithdrawalsEnabled Stores the state of the withdrawals
    struct State {
        bool isInitialized;
        bool isDepositsEnabled;
        bool isWithdrawalsEnabled;
    }


    bytes32 public constant DEPOSITS_ENABLER_ROLE =
    keccak256("BridgingManager.DEPOSITS_ENABLER_ROLE");
    bytes32 public constant DEPOSITS_DISABLER_ROLE =
    keccak256("BridgingManager.DEPOSITS_DISABLER_ROLE");
    bytes32 public constant WITHDRAWALS_ENABLER_ROLE =
    keccak256("BridgingManager.WITHDRAWALS_ENABLER_ROLE");
    bytes32 public constant WITHDRAWALS_DISABLER_ROLE =
    keccak256("BridgingManager.WITHDRAWALS_DISABLER_ROLE");

    /// @dev The location of the slot with State
    bytes32 private constant STATE_SLOT =
    keccak256("BridgingManager.bridgingState");



    modifier onlyNonZeroAccount(address account_) {
        if (account_ == address(0)) {
            revert ErrorAccountIsZeroAddress();
        }
        _;
    }


    /// @notice Returns whether the contract is initialized or not
    function isInitialized() public view returns (bool) {
        return _loadState().isInitialized;
    }

    /// @notice Returns whether the deposits are enabled or not
    function isDepositsEnabled() public view returns (bool) {
        return _loadState().isDepositsEnabled;
    }

    /// @notice Returns whether the withdrawals are enabled or not
    function isWithdrawalsEnabled() public view returns (bool) {
        return _loadState().isWithdrawalsEnabled;
    }

    /// @notice Enables the deposits if they are disabled
    function enableDeposits() external onlyOwner {

        if (isDepositsEnabled()) {
            revert ErrorDepositsEnabled();
        }
        _loadState().isDepositsEnabled = true;


        emit DepositsEnabled(msg.sender);
    }

    /// @notice Disables the deposits if they aren't disabled yet
    function disableDeposits()
    external
    whenDepositsEnabled
    onlyOwner
    {
        _loadState().isDepositsEnabled = false;
        emit DepositsDisabled(msg.sender);
    }

    /// @notice Enables the withdrawals if they are disabled
    function enableWithdrawals() external onlyOwner {
        if (isWithdrawalsEnabled()) {
            revert ErrorWithdrawalsEnabled();
        }
        _loadState().isWithdrawalsEnabled = true;
        emit WithdrawalsEnabled(msg.sender);
    }

    /// @notice Disables the withdrawals if they aren't disabled yet
    function disableWithdrawals()
    external
    whenWithdrawalsEnabled
    onlyOwner
    {
        _loadState().isWithdrawalsEnabled = false;
        emit WithdrawalsDisabled(msg.sender);
    }

    /// @dev Returns the reference to the slot with State struct
    function _loadState() private pure returns (State storage r) {
        bytes32 slot = STATE_SLOT;
        assembly {
            r.slot := slot
        }
    }


    function onMessageInvocation(
        bytes calldata _data
    ) external virtual;


    /// @dev Validates that deposits are enabled
    modifier whenDepositsEnabled() {
        if (!isDepositsEnabled()) {
            revert ErrorDepositsDisabled();
        }
        _;
    }

    /// @dev Validates that withdrawals are enabled
    modifier whenWithdrawalsEnabled() {
        if (!isWithdrawalsEnabled()) {
            revert ErrorWithdrawalsDisabled();
        }
        _;
    }

    event DepositsEnabled(address indexed enabler);
    event DepositsDisabled(address indexed disabler);
    event WithdrawalsEnabled(address indexed enabler);
    event WithdrawalsDisabled(address indexed disabler);
    event Initialized(address indexed admin);
    event ERC20DepositInitiated(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount
    );

    event ERC20WithdrawalFinalized(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount
    );

    error ErrorDepositsEnabled();
    error ErrorDepositsDisabled();
    error ErrorWithdrawalsEnabled();
    error ErrorWithdrawalsDisabled();
    error ErrorAccountIsZeroAddress();

}
