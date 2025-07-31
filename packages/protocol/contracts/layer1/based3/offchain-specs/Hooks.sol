// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ISpecs.sol";

library Hooks {
    function blockHeadHook(
        ISpecs.ProposalData memory proposalData,
        ISpecs.ProtocolState memory protocolState
    )
        external
        returns (ISpecs.ProtocolState memory)
    { }
    function blockTailHool(
        ISpecs.ProposalData memory proposalData,
        ISpecs.ProtocolState memory protocolState
    )
        external
        returns (ISpecs.ProtocolState memory)
    { }
    function proposalHeadHook(
        ISpecs.ProposalData memory proposalData,
        ISpecs.ProtocolState memory protocolState
    )
        external
        returns (ISpecs.ProtocolState memory)
    { }
    function proposalTailHook(
        ISpecs.ProposalData memory proposalData,
        ISpecs.ProtocolState memory protocolState
    )
        external
        returns (ISpecs.ProtocolState memory)
    { }
}
