// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { LibCometVote } from "src/layer2/etna/libs/LibCometVote.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @title EtnaVoteKeys
/// @notice Signs registration proofs of possession and CometBFT votes for the staking contract
/// with test consensus keys.
library EtnaVoteKeys {
    /// @dev Signs the registration proof of possession of `_pk` for `_owner` at `_staking`.
    /// @param _pk The consensus private key.
    /// @param _staking The staking contract.
    /// @param _owner The bond owner, the registration's caller.
    /// @return The proof of possession.
    function popSig(
        uint256 _pk,
        IEtnaStaking _staking,
        address _owner
    )
        internal
        view
        returns (bytes memory)
    {
        return EtnaTestKeys.sig65(_pk, _staking.registerDigest(_owner));
    }

    /// @dev Signs `_vote` with `_pk` over keccak256 of its CometBFT sign bytes under `_chainId`.
    /// @param _pk The consensus private key.
    /// @param _vote The vote; its signature is replaced.
    /// @param _chainId The CometBFT chain id the vote is signed under.
    /// @return The vote with its signature.
    function signVote(
        uint256 _pk,
        IEtnaStaking.Vote memory _vote,
        bytes memory _chainId
    )
        internal
        pure
        returns (IEtnaStaking.Vote memory)
    {
        _vote.signature =
            EtnaTestKeys.sig65(_pk, keccak256(LibCometVote.signBytes(_vote, _chainId)));
        return _vote;
    }
}
