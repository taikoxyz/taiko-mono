// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../common/EssentialContract.sol";
import "../../common/LibStrings.sol";
import "../../L1/ITaikoL1.sol";

interface IHasRecipient {
    function recipient() external view returns (address);
}

/// @title ProverSet
/// @notice A contract that holds TKO token and acts as a Taiko prover. This contract will simply
/// relay `proveBlock` calls to _taikoL1 so msg.sender doesn't need to hold any TKO.
/// @custom:security-contact security@taiko.xyz
contract ProverSet is EssentialContract, IERC1271 {
    bytes4 private constant _EIP1271_MAGICVALUE = 0x1626ba7e;

    mapping(address prover => bool isProver) public isProver; // slot 1
    address public admin; // slot 2

    uint256[48] private __gap;

    event ProverEnabled(address indexed prover, bool indexed enabled);

    error INVALID_STATUS();
    error PERMISSION_DENIED();

    modifier onlyAuthorized() {
        if (msg.sender != admin && msg.sender != IHasRecipient(admin).recipient()) {
            revert PERMISSION_DENIED();
        }
        _;
    }

    modifier onlyProver() {
        if (!isProver[msg.sender]) revert PERMISSION_DENIED();
        _;
    }

    /// @notice Initializes the contract.
    function init(
        address _owner,
        address _admin,
        address _addressManager
    )
        external
        nonZeroAddr(_admin)
        initializer
    {
        __Essential_init(_owner, _addressManager);
        admin = _admin;
        _tko().approve(address(_taikoL1()), type(uint256).max);
    }

    /// @notice Receives ETH as fees.
    receive() external payable { }

    function approveAllowance(address _address, uint256 _allowance) external onlyOwner {
        _tko().approve(_address, _allowance);
    }

    /// @notice Enables or disables a prover.
    function enableProver(address _prover, bool _isProver) external onlyAuthorized {
        if (isProver[_prover] == _isProver) revert INVALID_STATUS();
        isProver[_prover] = _isProver;

        emit ProverEnabled(_prover, _isProver);
    }

    /// @notice Withdraws Taiko tokens back to the admin address.
    function withdrawToAdmin(uint256 _amount) external onlyAuthorized {
        _tko().transfer(admin, _amount);
    }

    /// @notice Propose a Taiko block.
    function proposeBlock(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        payable
        onlyProver
        nonReentrant
    {
        _taikoL1().proposeBlock(_params, _txList);
    }

    /// @notice Proves or contests a Taiko block.
    function proveBlock(uint64 _blockId, bytes calldata _input) external onlyProver nonReentrant {
        _taikoL1().proveBlock(_blockId, _input);
    }

    /// @notice Deposits Taiko token to _taikoL1 contract.
    function depositBond(uint256 _amount) external onlyAuthorized nonReentrant {
        _taikoL1().depositBond(_amount);
    }

    /// @notice Withdraws Taiko token from _taikoL1 contract.
    function withdrawBond(uint256 _amount) external onlyAuthorized nonReentrant {
        _taikoL1().withdrawBond(_amount);
    }

    /// @notice Delegates token voting right to a delegatee.
    /// @param _delegatee The delegatee to receive the voting right.
    function delegate(address _delegatee) external onlyAuthorized nonReentrant {
        _tko().delegate(_delegatee);
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

    function _taikoL1() private view returns (ITaikoL1) {
        return ITaikoL1(resolve(LibStrings.B_TAIKO, false));
    }

    function _tko() private view returns (ERC20VotesUpgradeable) {
        return ERC20VotesUpgradeable(resolve(LibStrings.B_TAIKO_TOKEN, false));
    }
}
