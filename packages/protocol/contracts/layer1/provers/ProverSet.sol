// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../shared/common/EssentialContract.sol";
import "../../shared/common/LibStrings.sol";
import "../../shared/common/LibAddress.sol";
import "../based/ITaikoL1.sol";

interface IHasRecipient {
    function recipient() external view returns (address);
}

/// @title ProverSet
/// @notice A contract that holds TKO token and acts as a Taiko prover. This contract will simply
/// relay `proveBlock` calls to TaikoL1 so msg.sender doesn't need to hold any TKO.
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
        address _rollupAddressManager
    )
        external
        nonZeroAddr(_admin)
        initializer
    {
        __Essential_init(_owner, _rollupAddressManager);
        admin = _admin;
        IERC20(tkoToken()).approve(taikoL1(), type(uint256).max);
    }

    /// @notice Receives ETH as fees.
    receive() external payable { }

    function approveAllowance(address _address, uint256 _allowance) external onlyOwner {
        IERC20(tkoToken()).approve(_address, _allowance);
    }

    /// @notice Enables or disables a prover.
    function enableProver(address _prover, bool _isProver) external onlyAuthorized {
        if (isProver[_prover] == _isProver) revert INVALID_STATUS();
        isProver[_prover] = _isProver;

        emit ProverEnabled(_prover, _isProver);
    }

    /// @notice Withdraws Taiko tokens back to the admin address.
    function withdrawToAdmin(uint256 _amount) external onlyAuthorized {
        IERC20(tkoToken()).transfer(admin, _amount);
    }

    /// @notice Withdraws ETH back to the owner address.
    function withdrawEtherToAdmin(uint256 _amount) external onlyAuthorized {
        LibAddress.sendEtherAndVerify(admin, _amount);
    }

    /// @notice Propose a Taiko block.
    function proposeBlock(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        payable
        onlyProver
    {
        ITaikoL1(taikoL1()).proposeBlock(_params, _txList);
    }

    /// @notice Propose a Taiko block.
    function proposeBlockV2(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        payable
        onlyProver
    {
        ITaikoL1(taikoL1()).proposeBlockV2(_params, _txList);
    }

    /// @notice Propose multiple Taiko blocks.
    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        payable
        onlyProver
    {
        ITaikoL1(taikoL1()).proposeBlocksV2(_paramsArr, _txListArr);
    }

    /// @notice Proves or contests a Taiko block.
    function proveBlock(uint64 _blockId, bytes calldata _input) external onlyProver  {
        ITaikoL1(taikoL1()).proveBlock(_blockId, _input);
    }

    /// @notice Batch proves or contests Taiko blocks.
    function proveBlocks(
        uint64[] calldata _blockId,
        bytes[] calldata _input,
        bytes calldata _batchProof
    )
        external
        onlyProver
    {
        ITaikoL1(taikoL1()).proveBlocks(_blockId, _input, _batchProof);
    }

    /// @notice Deposits Taiko token to TaikoL1 contract.
    function depositBond(uint256 _amount) external onlyAuthorized  {
        ITaikoL1(taikoL1()).depositBond(_amount);
    }

    /// @notice Withdraws Taiko token from TaikoL1 contract.
    function withdrawBond(uint256 _amount) external onlyAuthorized  {
        ITaikoL1(taikoL1()).withdrawBond(_amount);
    }

    /// @notice Delegates token voting right to a delegatee.
    /// @param _delegatee The delegatee to receive the voting right.
    function delegate(address _delegatee) external onlyAuthorized nonReentrant {
        ERC20VotesUpgradeable(tkoToken()).delegate(_delegatee);
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

    function taikoL1() internal view virtual returns (address) {
        return resolve(LibStrings.B_TAIKO, false);
    }

    function tkoToken() internal view virtual returns (address) {
        return resolve(LibStrings.B_TAIKO_TOKEN, false);
    }
}
