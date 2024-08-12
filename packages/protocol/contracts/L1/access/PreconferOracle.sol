// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./IProposerAccess.sol";

interface IPreconferRegistry {
    function isElegiblePreconfer(address account) external view returns (bool);
}

/// @title PreconferOracle
/// @custom:security-contact security@taiko.xyz
contract PreconferOracle is IProposerAccess {
    IPreconferRegistry public preconferRegistry;

    struct Preconfer {
        uint64 blockHeight;
        address proposer;
        address preconfer;
    }

    mapping(uint256 blockId_mod_64 => Preconfer) public slots;
    uint256 latestBlockId;

    function setProposer(uint64 blockHeight, address proposer) external {
        address preconfer = preconferRegistry.isElegiblePreconfer(proposer) ? proposer : address(0);
        slots[blockHeight % 64] = Preconfer(blockHeight, proposer, preconfer);
    }

    function challange(Preconfer calldata _preconfer) external { }

    function isPreconfer(address _proposer, uint256 _blockHeight) external view returns (bool) { }
}
