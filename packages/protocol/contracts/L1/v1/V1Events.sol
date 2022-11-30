// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../LibData.sol";

/// @author david <david@taiko.xyz>
abstract contract V1Events {
    // The following events must match the definitions in other V1 libraries.
    event BlockVerified(uint256 indexed id, bytes32 blockHash);

    event BlockCommitted(
        uint64 commitSlot,
        uint64 commitHeight,
        bytes32 commitHash
    );

    event BlockProposed(uint256 indexed id, LibData.BlockMetadata meta);

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        uint64 timestamp,
        uint64 provenAt,
        address prover
    );

    event WhitelistingEnabled(bool whitelistProposers, bool whitelistProvers);

    event ProposerWhitelisted(address indexed prover, bool whitelisted);

    event ProverWhitelisted(address indexed prover, bool whitelisted);

    event Halted(bool halted);
}
