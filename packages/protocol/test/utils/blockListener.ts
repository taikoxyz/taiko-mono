import type { SimpleChannel } from "channel-ts";
import { ethers } from "ethers";

// blockListener should be called as follows:
// `l2Provider.on("block", blockListener(chan, genesisHeight, l2Provider, maxNumBlocks))`
// it will send incoming blockNumbers, generated from the l2 provider on a new block,
// through a Golang-style channel, which can then be waited on like such:
// for await (const blockNumber of chan)
// so we can then run a commit, propose, prove, and verify flow in our test cases
// in the main javascript event loop, instead of in the event handler of the l2Provider
// itself.

const blockListener = function (
    chan: SimpleChannel<number>,
    genesisHeight: number,
    l2Provider: ethers.providers.JsonRpcProvider,
    maxNumBlocks: number
) {
    return function (blockNumber: number) {
        if (blockNumber < genesisHeight) return;
        if (blockNumber > genesisHeight + (maxNumBlocks - 1)) {
            chan.close();
            l2Provider.off("block");
            return;
        }

        chan.send(blockNumber);
    };
};

export default blockListener;
