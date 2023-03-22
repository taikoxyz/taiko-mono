import type { SimpleChannel } from "channel-ts";

// blockListener should be called as follows:
// `l2Provider.on("block", blockListener(chan, genesisHeight)`
// it will send incoming blockNumbers, generated from the l2 provider on a new block,
// through a Golang-style channel, which can then be waited on like such:
// for await (const blockNumber of chan)
// so we can then run a  propose, prove, and verify flow in our test cases
// in the main javascript event loop, instead of in the event handler of the l2Provider
// itself.

const blockListener = function (
    chan: SimpleChannel<number>,
    genesisHeight: number
) {
    let notFirstEvent = false;

    return function (blockNumber: number) {
        if (blockNumber <= genesisHeight) return;
        // Sometimes the first block number will be greater than start height,
        // we need to fill the gap manually.
        if (!notFirstEvent) {
            if (blockNumber > genesisHeight) {
                for (let i = genesisHeight + 1; i < blockNumber; i++) {
                    chan.send(i);
                }
            }
            notFirstEvent = true;
        }
        chan.send(blockNumber);
    };
};

export default blockListener;
