// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/libs/LibAddress.sol";
import "../based/ITaikoInbox.sol";

interface IHasRecipient {
    function recipient() external view returns (address);
}

/// @title ProverSetBase
/// @notice A contract that holds TAIKO token and acts as a Taiko prover. This contract will simply
/// relay `proveBlock` calls to TaikoL1 so msg.sender doesn't need to hold any TAIKO.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
abstract contract ProverSetBase is EssentialContract, IERC1271 {
    bytes4 private constant _EIP1271_MAGICVALUE = 0x1626ba7e;

    address public immutable inbox;
    address public immutable bondToken;

    mapping(address prover => bool isProver) public isProver; // slot 1
    address public admin; // slot 2

    uint256[48] private __gap;

    event ProverEnabled(address indexed prover, bool indexed enabled);

    error INVALID_STATUS();
    error PERMISSION_DENIED();
    error NOT_FIRST_PROPOSAL();

    modifier onlyAuthorized() {
        require(
            msg.sender == admin || msg.sender == IHasRecipient(admin).recipient(),
            PERMISSION_DENIED()
        );
        _;
    }

    modifier onlyProver() {
        require(isProver[msg.sender], PERMISSION_DENIED());
        _;
    }

    constructor(address _inbox, address _bondToken) nonZeroAddr(_inbox) nonZeroAddr(_bondToken) {
        inbox = _inbox;
        bondToken = _bondToken;
    }

    receive() external payable { }

    /// @notice Initializes the contract.
    function init(address _owner, address _admin) external nonZeroAddr(_admin) initializer {
        __Essential_init(_owner);
        admin = _admin;

        IERC20(bondToken).approve(inbox, type(uint256).max);
    }

    function approveAllowance(address _address, uint256 _allowance) external onlyOwner {
        IERC20(bondToken).approve(_address, _allowance);
    }

    /// @notice Enables or disables a prover.
    function enableProver(address _prover, bool _isProver) external onlyAuthorized {
        require(isProver[_prover] != _isProver, INVALID_STATUS());
        isProver[_prover] = _isProver;

        emit ProverEnabled(_prover, _isProver);
    }

    /// @notice Withdraws Taiko tokens back to the admin address.
    function withdrawToAdmin(uint256 _amount) external onlyAuthorized {
        require(IERC20(bondToken).transfer(admin, _amount), TransferFailed());
    }

    /// @notice Withdraws ETH back to the owner address.
    function withdrawEtherToAdmin(uint256 _amount) external onlyAuthorized {
        LibAddress.sendEtherAndVerify(admin, _amount);
    }

    /// @notice Deposits Taiko token to Taiko contract.
    function depositBond(uint256 _amount) external onlyAuthorized {
        ITaikoInbox(inbox).v4DepositBond(_amount);
    }

    /// @notice Withdraws Taiko token from Taiko contract.
    function withdrawBond(uint256 _amount) external onlyAuthorized {
        ITaikoInbox(inbox).v4WithdrawBond(_amount);
    }

    /// @notice Delegates token voting right to a delegatee.
    /// @param _delegatee The delegatee to receive the voting right.
    function delegate(address _delegatee) external onlyAuthorized {
        ERC20VotesUpgradeable(bondToken).delegate(_delegatee);
    }

    // This function is necessary for this contract to become an assigned prover.
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    )
        external
        view
        returns (bytes4 magicValue_)
    {
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(_hash, _signature);
        if (error == ECDSA.RecoverError.NoError && isProver[recovered]) {
            magicValue_ = _EIP1271_MAGICVALUE;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error TransferFailed();
}
