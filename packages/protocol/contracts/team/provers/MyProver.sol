// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../common/EssentialContract.sol";
import "../../L1/ITaikoL1.sol";

/// @title ProverSet
/// @notice A contract that holds TKO token and acts as a Taiko prover. This contract will simply
/// relay `proveBlock` calls to TaikoL1 so msg.sender doesn't need to hold any TKO.
/// @custom:security-contact security@taiko.xyz
contract ProverSet is EssentialContract {
    address public constant TKO = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    address public constant TAIKO = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
    address public constant ASSIGNMENT_HOOK = 0x537a2f0D3a5879b41BCb5A2afE2EA5c4961796F6;

    mapping(address prover => bool isProver) public isProver;
    uint256[49] private __gap;

    event ProverEnabled(address indexed addr, bool indexed enabled);

    error INVALID_STATUS();
    error PERMISSION_DENIED();

    /// @notice Initializes the contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
        IERC20(TKO).approve(TAIKO, type(uint256).max);
        IERC20(TKO).approve(ASSIGNMENT_HOOK, type(uint256).max);
    }

    /// @notice Enables or disables a prover.
    function enableProver(address _prover, bool _isProver) external onlyOwner {
        if (isProver[_prover] == _isProver) revert INVALID_STATUS();
        isProver[_prover] = _isProver;

        emit ProverEnabled(_prover, _isProver);
    }

    /// @notice Withdraws Taiko tokens back to the owner address.
    function withdraw(uint256 _amount) external onlyOwner {
        IERC20(TKO).transfer(owner(), _amount);
    }

    /// @notice Proves or contests a Taiko block.
    function proveBlock(uint64 _blockId, bytes calldata _input) external whenNotPaused {
        if (!isProver[msg.sender]) revert PERMISSION_DENIED();

        ITaikoL1(TAIKO).proveBlock(_blockId, _input);
    }
}
