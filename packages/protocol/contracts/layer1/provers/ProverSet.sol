// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/libs/LibAddress.sol";
import "../based/ITaikoInbox.sol";

interface IHasRecipient {
    function recipient() external view returns (address);
}

/// @title ProverSet
/// @notice A contract that holds TAIKO token and acts as a Taiko prover. This contract will simply
/// relay `proveBlock` calls to TaikoL1 so msg.sender doesn't need to hold any TAIKO.
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
            IERC20(_bondToken).approve(inbox(), type(uint256).max);
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

    /// @notice Propose multiple Taiko blocks.
    function proposeBlocksV3(
        ITaikoInbox.BlockParamsV3[] calldata _paramsArray,
        bytes calldata _txList,
        bool _revertIfNotFirstProposal
    )
        external
        onlyProver
    {
        ITaikoInbox taiko = ITaikoInbox(inbox());
        if (_revertIfNotFirstProposal) {
            // Ensure this block is the first block proposed in the current L1 block.
            require(taiko.getStats2().lastProposedIn != block.number, NOT_FIRST_PROPOSAL());
        }
        taiko.proposeBlocksV3(address(0), address(0), _paramsArray, _txList);
    }

    /// @notice Batch proves or contests Taiko blocks.
    function proveBlocksV3(
        ITaikoInbox.BlockMetadataV3[] calldata _metas,
        ITaikoInbox.TransitionV3[] calldata _transitions,
        bytes calldata _proof
    )
        external
        onlyProver
    {
        ITaikoInbox(inbox()).proveBlocksV3(_metas, _transitions, _proof);
    }

    /// @notice Deposits Taiko token to Taiko contract.
    function depositBond(uint256 _amount) external onlyAuthorized {
        ITaikoInbox(inbox()).depositBond(_amount);
    }

    /// @notice Withdraws Taiko token from Taiko contract.
    function withdrawBond(uint256 _amount) external onlyAuthorized {
        ITaikoInbox(inbox()).withdrawBond(_amount);
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

    function inbox() internal view virtual returns (address) {
        return resolve(LibStrings.B_TAIKO, false);
    }

    function bondToken() internal view virtual returns (address) {
        return resolve(LibStrings.B_BOND_TOKEN, true);
    }
}
