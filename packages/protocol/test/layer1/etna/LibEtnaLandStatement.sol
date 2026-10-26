// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";

/// @title LibEtnaLandStatement
/// @notice Rebuilds the appendix A landing hashes, the cut leaf, the cut hash and the 21-word
/// landing statement, with flat `abi.encode` and independently of `EtnaInbox`.
/// @dev Shared by `EtnaLandTestBase` and the invariant handler. The caller supplies every value the
/// Inbox reads from storage or its immutables, so it decides whether they come from the Inbox's
/// getters or from a model.
library LibEtnaLandStatement {
    /// @dev The statement words that are deployment constants or stored Inbox values; the L1 chain
    /// id is `block.chainid`.
    struct Context {
        uint256 l2ChainId;
        address inbox;
        address stakingRegistry;
        uint256 generation;
        bytes32 committeeConfigHash;
    }

    /// @dev `cutLeaf(x) = keccak256(abi.encode(x, blockHash, cometHash, forcedHead))`.
    function leaf(
        uint256 _x,
        bytes32 _el,
        bytes32 _comet,
        uint256 _head
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_x, _el, _comet, _head));
    }

    /// @dev `cutHash = keccak256(abi.encode(bytes32("ETNA_LAND_CUTS_V1"), generation, p, h,
    /// keccak256(abi.encodePacked(leaves))))`.
    function cutHash(
        uint256 _generation,
        uint256 _p,
        uint256 _h,
        bytes32[] memory _leaves
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                bytes32("ETNA_LAND_CUTS_V1"),
                _generation,
                _p,
                _h,
                keccak256(abi.encodePacked(_leaves))
            )
        );
    }

    /// @dev The 672-byte statement preimage: the 21 appendix A words, with parentHash,
    /// parentCometHash and headBefore from `_origin`, the reference block hash `_referenceHash`
    /// and the hash of `_blobHashes`.
    function preimage(
        Context memory _ctx,
        IEtnaInbox.LandInput memory _in,
        IEtnaInbox.Landing memory _origin,
        bytes32 _referenceHash,
        bytes32[] memory _blobHashes,
        bytes32 _cutHash
    )
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(
            _words0To6(_ctx, _in),
            _words7To13(_ctx, _in, _origin),
            _words14To20(_in, _origin, _referenceHash, _blobHashes, _cutHash)
        );
    }

    /// @dev Statement words 0-6: tag, L1 chain id, L2 chain id, Inbox, registry, generation, p.
    function _words0To6(
        Context memory _ctx,
        IEtnaInbox.LandInput memory _in
    )
        private
        view
        returns (bytes memory)
    {
        return abi.encode(
            bytes32("TAIKO_ETNA_LAND_V1"),
            block.chainid,
            _ctx.l2ChainId,
            _ctx.inbox,
            _ctx.stakingRegistry,
            _ctx.generation,
            _in.parentHeight
        );
    }

    /// @dev Statement words 7-13: parentHash, parentCometHash, committeeConfigHash, h,
    /// lastBlockHash, lastCometHash, lastStateRoot.
    function _words7To13(
        Context memory _ctx,
        IEtnaInbox.LandInput memory _in,
        IEtnaInbox.Landing memory _origin
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encode(
            _origin.elHash,
            _origin.cometHash,
            _ctx.committeeConfigHash,
            _in.lastHeight,
            _in.lastBlockHash,
            _in.lastCometHash,
            _in.lastStateRoot
        );
    }

    /// @dev Statement words 14-20: reference number and hash, blob hashes hash, headBefore,
    /// headAfter, activeCommitteeSnapshot, cutHash.
    function _words14To20(
        IEtnaInbox.LandInput memory _in,
        IEtnaInbox.Landing memory _origin,
        bytes32 _referenceHash,
        bytes32[] memory _blobHashes,
        bytes32 _cutHash
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encode(
            _in.l1ReferenceBlockNumber,
            _referenceHash,
            keccak256(abi.encodePacked(_blobHashes)),
            uint256(_origin.head),
            _in.forcedInclusionHead,
            _in.activeCommitteeSnapshot,
            _cutHash
        );
    }
}
