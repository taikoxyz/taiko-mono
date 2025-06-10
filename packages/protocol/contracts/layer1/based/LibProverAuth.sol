// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title LibProverAuth
/// @notice This library is used to validate the prover authentication.
/// @dev This library's validateProverAuth function is made public to reduce TaikoInbox's code size
/// .
/// @custom:security-contact security@taiko.xyz
library LibProverAuth {
    using ECDSA for bytes32;

    struct ProverAuth {
        uint96 fee;
        uint64 validUntil;
        bytes signature;
    }

    error InvalidValidUntil();

    function validateProverAuth(
        bytes32 _dataHash,
        bytes calldata _proverAuth
    )
        public
        view
        returns (address prover_, uint96 fee_)
    {
        ProverAuth memory auth = abi.decode(_proverAuth, (ProverAuth));

        require(auth.validUntil == 0 || auth.validUntil >= block.timestamp, InvalidValidUntil());

        bytes memory signature = auth.signature;
        auth.signature = ""; // clear the signature before hashing

        prover_ = keccak256(abi.encode("PROVER_AUTHENTICATION", auth, _dataHash)).recover(signature);
        fee_ = auth.fee;
    }
}
