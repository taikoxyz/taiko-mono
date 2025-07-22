// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

// TODO(daniel): implement these funcitons
library LibCodec {
    function encodeBatchContext(I.BatchContext memory _context)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_context);
    }

    function encodeTransitionMetas(I.TransitionMeta[] memory _transitionMetas)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_transitionMetas);
    }

    function encodeSummary(I.Summary memory _summary) internal pure returns (bytes memory) {
        return abi.encode(_summary);
    }

    function decodeProposeBatchesInputs(bytes memory _data)
        internal
        pure
        returns (
            I.Summary memory,
            I.Batch[] memory,
            I.BatchProposeMetadataEvidence memory,
            I.TransitionMeta[] memory
        )
    { }

    function decodeProverAuth(bytes memory _data) internal pure returns (I.ProverAuth memory) { }

    function decodeSummary(bytes memory _data) internal pure returns (I.Summary memory) {
        return abi.decode(_data, (I.Summary));
    }

    function decodeProveBatchesInputs(bytes memory _data)
        internal
        pure
        returns (I.BatchProveInput[] memory)
    { }
}
