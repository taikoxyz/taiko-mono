// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@eth-fabric/urc/ISlasher.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";

contract MockLookaheadStore {
    mapping(uint256 => bytes26) internal lookaheadHashes;

    function setLookaheadHash(uint256 _epochTimestamp, bytes26 _lookaheadHash) public {
        lookaheadHashes[_epochTimestamp] = _lookaheadHash;
    }

    function getLookaheadHash(uint256 _epochTimestamp) external view returns (bytes26) {
        return lookaheadHashes[_epochTimestamp];
    }

    function updateLookahead(
        bytes32 _registrationRoot,
        bytes calldata _data
    )
        external
        returns (bytes26 lookaheadHash_)
    {
        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp(1);

        if (_registrationRoot == bytes32(0)) {
            ILookaheadStore.LookaheadSlot[] memory lookaheadSlots =
                abi.decode(_data, (ILookaheadStore.LookaheadSlot[]));
            setLookaheadHash(epochTimestamp, calculateLookaheadHash(epochTimestamp, lookaheadSlots));
        } else {
            ISlasher.SignedCommitment memory signedCommitment =
                abi.decode(_data, (ISlasher.SignedCommitment));
            ILookaheadStore.LookaheadSlot[] memory lookaheadSlots =
                abi.decode(signedCommitment.commitment.payload, (ILookaheadStore.LookaheadSlot[]));
            setLookaheadHash(epochTimestamp, calculateLookaheadHash(epochTimestamp, lookaheadSlots));
        }

        return lookaheadHashes[epochTimestamp];
    }

    function calculateLookaheadHash(
        uint256 _epochTimestamp,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
    )
        public
        pure
        returns (bytes26)
    {
        return LibPreconfUtils.calculateLookaheadHash(_epochTimestamp, _lookaheadSlots);
    }
}
