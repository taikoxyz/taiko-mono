// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/libs/LibAddress.sol";
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
    error INVALID_BOND_TOKEN();
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

    /// @notice Initializes the contract.
    function init(
        address _owner,
        address _admin,
        address _rollupResolver
    )
        external
        nonZeroAddr(_admin)
        initializer
    {
        __Essential_init(_owner, _rollupResolver);
        admin = _admin;

        address _bondToken = bondToken();
        if (_bondToken != address(0)) {
            IERC20(_bondToken).approve(taikoL1(), type(uint256).max);
        }
    }

    function approveAllowance(address _address, uint256 _allowance) external onlyOwner {
        address _bondToken = bondToken();
        require(_bondToken != address(0), INVALID_BOND_TOKEN());
        IERC20(_bondToken).approve(_address, _allowance);
    }

    /// @notice Enables or disables a prover.
    function enableProver(address _prover, bool _isProver) external onlyAuthorized {
        require(isProver[_prover] != _isProver, INVALID_STATUS());
        isProver[_prover] = _isProver;

        emit ProverEnabled(_prover, _isProver);
    }

    /// @notice Withdraws Taiko tokens back to the admin address.
    function withdrawToAdmin(uint256 _amount) external onlyAuthorized {
        address _bondToken = bondToken();
        if (_bondToken != address(0)) {
            IERC20(_bondToken).transfer(admin, _amount);
        } else {
            LibAddress.sendEtherAndVerify(admin, _amount);
        }
    }

    /// @notice Withdraws ETH back to the owner address.
    function withdrawEtherToAdmin(uint256 _amount) external onlyAuthorized {
        LibAddress.sendEtherAndVerify(admin, _amount);
    }

    /// @notice Proposes a block only when it is the first block proposal in the current L1 block.
    function proposeBlocksConditionally(bytes[] calldata _paramsArr) external onlyProver {
        ITaikoL1 taiko = ITaikoL1(taikoL1());
        // Ensure this block is the first block proposed in the current L1 block.
        require(taiko.lastProposedIn() != block.number, NOT_FIRST_PROPOSAL());
        // TODO(danielw):fix this
        // taiko.proposeBlocksV3(_paramsArr);
    }

    /// @notice Propose multiple Taiko blocks.
    function proposeBlocks(bytes[] calldata _paramsArr) external onlyProver {
        // TODO(danielw):fix this
        // ITaikoL1(taikoL1()).proposeBlocksV3(_paramsArr);
    }

    /// @notice Batch proves or contests Taiko blocks.
    function proveBlocks(
        uint64[] calldata _blockId,
        bytes[] calldata _input,
        bytes calldata _batchProof
    )
        external
        onlyProver
    { // TODO(danielw):fix this
            // ITaikoL1(taikoL1()).proveBlocksV3(_blockId, _input, _batchProof);
    }

    /// @notice Deposits Taiko token to TaikoL1 contract.
    function depositBond(uint256 _amount) external onlyAuthorized {
        ITaikoL1(taikoL1()).depositBond(_amount);
    }

    /// @notice Withdraws Taiko token from TaikoL1 contract.
    function withdrawBond(uint256 _amount) external onlyAuthorized {
        ITaikoL1(taikoL1()).withdrawBond(_amount);
    }

    /// @notice Delegates token voting right to a delegatee.
    /// @param _delegatee The delegatee to receive the voting right.
    function delegate(address _delegatee) external onlyAuthorized {
        address _bondToken = bondToken();
        require(_bondToken != address(0), INVALID_BOND_TOKEN());
        ERC20VotesUpgradeable(_bondToken).delegate(_delegatee);
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

    function bondToken() internal view virtual returns (address) {
        return resolve(LibStrings.B_BOND_TOKEN, true);
    }
}
