// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IRegistrationMptVerifierV2 } from "../iface/IRegistrationMptVerifierV2.sol";

/// @title Slot Chain destination-registration statement codec
/// @custom:security-contact security@taiko.xyz
library LibRegistrationStatementV2 {
    bytes32 private constant _STATEMENT_TYPEHASH =
        0xc049f967468e58f1a5c9b9e1a147dfc233695ae69c5d4a95ec4ffb49b5687da0;

    /// @dev Returns the frozen public-input schema hash and statement type hash.
    function publicInputSchemaHash() internal pure returns (bytes32 hash_) {
        return _STATEMENT_TYPEHASH;
    }

    /// @dev Hashes all twelve statement fields in their normative ABI order.
    /// @param _statement The complete caller-derived destination-registration statement in memory.
    /// @return statementHash_ The exact statement commitment.
    function hashStatement(
        IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory _statement
    )
        internal
        pure
        returns (bytes32 statementHash_)
    {
        return keccak256(
            abi.encode(
                _STATEMENT_TYPEHASH,
                _statement.settlementChainId,
                _statement.activeSettlementRouter,
                _statement.bridgeDomainRegistry,
                _statement.routeKey,
                _statement.destinationChainId,
                _statement.protocolVersion,
                _statement.canonicalSequence,
                _statement.stateRoot,
                _statement.terminalDomainRegistrar,
                _statement.registrarCodeHash,
                _statement.storageTrieKey,
                _statement.expectedValue
            )
        );
    }
}
