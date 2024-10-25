// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/common/LibStrings.sol";
import "src/shared/common/LibAddress.sol";
import "../based/ITaikoL1.sol";

/// @title IHasRecipient
/// @notice Interface to get the recipient address.
/// @dev This interface is used to retrieve the recipient address associated with a contract.
interface IHasRecipient {
    /// @notice Returns the recipient address.
    /// @return The address of the recipient.
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
    /// @param _owner The owner of the contract.
    /// @param _admin The admin of the contract.
    /// @param _rollupAddressManager The address of the rollup address manager.
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

    /// @notice Approves allowance for a given address.
    /// @param _address The address to approve allowance for.
    /// @param _allowance The amount of allowance to approve.
    function approveAllowance(address _address, uint256 _allowance) external onlyOwner {
        IERC20(tkoToken()).approve(_address, _allowance);
    }

    /// @notice Enables or disables a prover.
    /// @param _prover The address of the prover.
    /// @param _isProver The status to set for the prover.
    function enableProver(address _prover, bool _isProver) external onlyAuthorized {
        if (isProver[_prover] == _isProver) revert INVALID_STATUS();
        isProver[_prover] = _isProver;

        emit ProverEnabled(_prover, _isProver);
    }

    /// @notice Withdraws Taiko tokens back to the admin address.
    /// @param _amount The amount of tokens to withdraw.
    function withdrawToAdmin(uint256 _amount) external onlyAuthorized {
        IERC20(tkoToken()).transfer(admin, _amount);
    }

    /// @notice Withdraws ETH back to the owner address.
    /// @param _amount The amount of ETH to withdraw.
    function withdrawEtherToAdmin(uint256 _amount) external onlyAuthorized {
        LibAddress.sendEtherAndVerify(admin, _amount);
    }

    /// @notice Propose a Taiko block.
    /// @param _params The parameters for the block proposal.
    /// @param _txList The transaction list for the block proposal.
    function proposeBlockV2(bytes calldata _params, bytes calldata _txList) external onlyProver {
        ITaikoL1(taikoL1()).proposeBlockV2(_params, _txList);
    }

    /// @notice Propose multiple Taiko blocks.
    /// @param _paramsArr The array of parameters for the block proposals.
    /// @param _txListArr The array of transaction lists for the block proposals.
    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        onlyProver
    {
        ITaikoL1(taikoL1()).proposeBlocksV2(_paramsArr, _txListArr);
    }

    /// @notice Proves or contests a Taiko block.
    /// @param _blockId The ID of the block to prove or contest.
    /// @param _input The input data for the proof or contest.
    function proveBlock(uint64 _blockId, bytes calldata _input) external onlyProver {
        ITaikoL1(taikoL1()).proveBlock(_blockId, _input);
    }

    /// @notice Batch proves or contests Taiko blocks.
    /// @param _blockId The array of block IDs to prove or contest.
    /// @param _input The array of input data for the proofs or contests.
    /// @param _batchProof The batch proof data.
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
    /// @param _amount The amount of tokens to deposit.
    function depositBond(uint256 _amount) external onlyAuthorized {
        ITaikoL1(taikoL1()).depositBond(_amount);
    }

    /// @notice Withdraws Taiko token from TaikoL1 contract.
    /// @param _amount The amount of tokens to withdraw.
    function withdrawBond(uint256 _amount) external onlyAuthorized {
        ITaikoL1(taikoL1()).withdrawBond(_amount);
    }

    /// @notice Delegates token voting right to a delegatee.
    /// @param _delegatee The delegatee to receive the voting right.
    function delegate(address _delegatee) external onlyAuthorized nonReentrant {
        ERC20VotesUpgradeable(tkoToken()).delegate(_delegatee);
    }

    /// @notice Checks if a signature is valid.
    /// @param _hash The hash of the data to be signed.
    /// @param _signature The signature to validate.
    /// @return magicValue_ The magic value if the signature is valid.
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

    /// @dev Resolves the address of the TaikoL1 contract.
    /// @return The address of the TaikoL1 contract.
    function taikoL1() internal view virtual returns (address) {
        return resolve(LibStrings.B_TAIKO, false);
    }

    /// @dev Resolves the address of the TKO token contract.
    /// @return The address of the TKO token contract.
    function tkoToken() internal view virtual returns (address) {
        return resolve(LibStrings.B_TAIKO_TOKEN, false);
    }
}
