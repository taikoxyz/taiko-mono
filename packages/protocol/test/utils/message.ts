type Message = {
    id: number;
    sender: string;
    srcChainId: number;
    destChainId: number;
    owner: string;
    to: string;
    refundAddress: string;
    depositValue: number;
    callValue: number;
    processingFee: number;
    gasLimit: number;
    data: string;
    memo: string;
};

const MessageStatus = {
    NEW: 0,
    RETRIABLE: 1,
    DONE: 2,
    FAILED: 3,
};

async function getMessageStatusSlot(hre: any, signal: any) {
    return hre.ethers.utils.solidityKeccak256(
        ["string", "bytes"],
        ["MESSAGE_STATUS", signal]
    );
}

export { Message, MessageStatus, getMessageStatusSlot };
