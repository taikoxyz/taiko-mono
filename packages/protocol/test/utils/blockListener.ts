import type { SimpleChannel } from "channel-ts";
import { ethers } from "ethers";

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
