// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "test/layer1/based/helpers/Verifier_ToggleStub.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/based/ForcedInclusionInbox.sol";
import "src/layer1/based/IForcedInclusionStore.sol";

abstract contract ForcedInclusionInboxTestBase is InboxTestBase {
    ForcedInclusionInbox internal forcedInclusionInbox;
    IForcedInclusionStore internal forcedInclusionStore;
    address owner;

    function setUpOnEthereum() internal virtual override {
        owner = Alice;

        genesisBlockProposedAt = block.timestamp;
        genesisBlockProposedIn = block.number;

        inbox = deployInbox(correctBlockhash(0), pacayaConfig());

        forcedInclusionStore = deployForcedInclusionStore(100, 100, owner);
        forcedInclusionInbox = deployForcedInclusionInbox();

        signalService = deploySignalService(address(new SignalService(address(resolver))));
        signalService.authorize(address(inbox), true);

        resolver.registerAddress(
            block.chainid, "proof_verifier", address(new Verifier_ToggleStub())
        );

        mineOneBlockAndWrap(12 seconds);
    }
}
