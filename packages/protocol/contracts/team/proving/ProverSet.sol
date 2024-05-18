// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../common/EssentialContract.sol";
import "../../common/LibStrings.sol";
import "../../L1/ITaikoL1.sol";

/// @title ProverSet
/// @notice A contract that holds TKO token and acts as a Taiko prover. This contract will simply
/// relay `proveBlock` calls to TaikoL1 so msg.sender doesn't need to hold any TKO.
/// @custom:security-contact security@taiko.xyz
contract ProverSet is EssentialContract, IERC1271 {
    bytes4 private constant _EIP1271_MAGICVALUE = 0x1626ba7e;

    mapping(address prover => bool isProver) public isProver;
    uint256[49] private __gap;

    event ProverEnabled(address indexed prover, bool indexed enabled);
    event BlockProvenBy(address indexed prover, uint64 indexed blockId);

    error INVALID_STATUS();
    error PERMISSION_DENIED();

    /// @notice Initializes the contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);

        IERC20 tko = IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false));

        address taikoL1 = resolve(LibStrings.B_TAIKO, false);
        tko.approve(taikoL1, type(uint256).max);

        address assignmentHook = resolve(LibStrings.B_ASSIGNMENT_HOOK, false);
        tko.approve(assignmentHook, type(uint256).max);
    }

    /// @notice Enables or disables a prover.
    function enableProver(address _prover, bool _isProver) external onlyOwner {
        if (isProver[_prover] == _isProver) revert INVALID_STATUS();
        isProver[_prover] = _isProver;

        emit ProverEnabled(_prover, _isProver);
    }

    /// @notice Withdraws Taiko tokens back to the owner address.
    function withdraw(uint256 _amount) external onlyOwner {
        IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false)).transfer(owner(), _amount);
    }

    /// @notice Proves or contests a Taiko block.
    function proveBlock(uint64 _blockId, bytes calldata _input) external whenNotPaused {
        if (!isProver[msg.sender]) revert PERMISSION_DENIED();

        emit BlockProvenBy(msg.sender, _blockId);
        ITaikoL1(resolve(LibStrings.B_TAIKO, false)).proveBlock(_blockId, _input);
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
}
