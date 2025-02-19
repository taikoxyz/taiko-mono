// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibStrings.sol";
import "../../verifiers/IVerifier.sol";

/// @title OpVerifier
/// @notice This contract is the implementation of verifying optimism signature proofs
/// onchain.
/// @custom:security-contact security@taiko.xyz
contract OpVerifier is EssentialContract, IVerifier {
    uint256[50] private __gap;

    constructor(address _resolver) EssentialContract(_resolver) { }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context[] calldata _ctxs,
        bytes calldata _proof
    )
        external
        onlyFromNamedEither(LibStrings.B_TAIKO, LibStrings.B_PROOF_VERIFIER)
    { }
}
