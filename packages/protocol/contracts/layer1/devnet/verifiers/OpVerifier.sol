// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "../../verifiers/IVerifier.sol";

/// @title OpVerifier
/// @notice This contract is the implementation of verifying optimism signature proofs
/// onchain.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
contract OpVerifier is EssentialContract, IVerifier {
    uint256[50] private __gap;


    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IVerifier
    function verifyProof(Context[] calldata _ctxs, bytes calldata _proof) external view { }
}
