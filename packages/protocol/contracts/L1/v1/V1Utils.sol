// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../../libs/LibMath.sol";
import "../LibData.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Utils {
    using LibMath for uint256;

    uint64 public constant MASK_HALT = 1 << 0;

    event WhitelistingEnabled(bool whitelistProposers, bool whitelistProvers);
    event ProposerWhitelisted(address indexed proposer, bool whitelisted);
    event ProverWhitelisted(address indexed prover, bool whitelisted);
    event Halted(bool halted);

    function enableWhitelisting(
        LibData.TentativeState storage tentative,
        bool whitelistProposers,
        bool whitelistProvers
    ) internal {
        tentative.whitelistProposers = whitelistProvers;
        tentative.whitelistProvers = whitelistProvers;
        emit WhitelistingEnabled(whitelistProposers, whitelistProvers);
    }

    function whitelistProposer(
        LibData.TentativeState storage tentative,
        address proposer,
        bool whitelisted
    ) internal {
        assert(tentative.whitelistProposers);
        require(
            proposer != address(0) &&
                tentative.proposers[proposer] != whitelisted,
            "L1:precondition"
        );

        tentative.proposers[proposer] = whitelisted;
        emit ProposerWhitelisted(proposer, whitelisted);
    }

    function whitelistProver(
        LibData.TentativeState storage tentative,
        address prover,
        bool whitelisted
    ) internal {
        assert(tentative.whitelistProvers);
        require(
            prover != address(0) && tentative.provers[prover] != whitelisted,
            "L1:precondition"
        );

        tentative.provers[prover] = whitelisted;
        emit ProverWhitelisted(prover, whitelisted);
    }

    function halt(LibData.State storage state, bool toHalt) internal {
        require(isHalted(state) != toHalt, "L1:precondition");
        setBit(state, MASK_HALT, toHalt);
        emit Halted(toHalt);
    }

    function isHalted(
        LibData.State storage state
    ) internal view returns (bool) {
        return isBitOne(state, MASK_HALT);
    }

    function isProposerWhitelisted(
        LibData.TentativeState storage tentative,
        address proposer
    ) internal view returns (bool) {
        assert(tentative.whitelistProposers);
        return tentative.proposers[proposer];
    }

    function isProverWhitelisted(
        LibData.TentativeState storage tentative,
        address prover
    ) internal view returns (bool) {
        assert(tentative.whitelistProvers);
        return tentative.provers[prover];
    }

    // Returns a deterministic deadline for uncle proof submission.
    function uncleProofDeadline(
        LibData.State storage state,
        LibData.ForkChoice storage fc
    ) internal view returns (uint64) {
        return fc.provenAt + state.avgProofTime;
    }

    function setBit(
        LibData.State storage state,
        uint64 mask,
        bool one
    ) private {
        state.statusBits = one
            ? state.statusBits | mask
            : state.statusBits & ~mask;
    }

    function isBitOne(
        LibData.State storage state,
        uint64 mask
    ) private view returns (bool) {
        return state.statusBits & mask != 0;
    }
}
