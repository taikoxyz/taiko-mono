import { L2Block } from "../test/types"
import { ethers } from "ethers"

export const DEFAULT_DEPLOY_CONFIRMATIONS = 12
export const TAIKO_CHAINID = 1337 // TODO: change chainId when it get registered

export const L2_GENESIS_BLOCK: L2Block = {
    header: {
        parentHash: ethers.constants.HashZero,
        ommersHash:
            "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347", // empty hash when no uncle
        beneficiary: ethers.constants.AddressZero,
        stateRoot: process.env.GENESIS_STATE_ROOT
            ? process.env.GENESIS_STATE_ROOT
            : "0x89a98e5c752ff4eb643384ccd158306220d55bbce46384a3f7dffe56805ebe73",
        transactionsRoot:
            "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", // empty hash when no tx
        receiptsRoot:
            "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", // empty hash when no tx
        logsBloom: Array(8).fill(ethers.constants.HashZero),
        difficulty: ethers.BigNumber.from("0"),
        height: ethers.BigNumber.from("0"),
        gasLimit: ethers.BigNumber.from("8000000"),
        gasUsed: ethers.BigNumber.from("0"),
        timestamp: ethers.BigNumber.from("0"),
        extraData: [],
        mixHash: ethers.constants.HashZero,
        nonce: ethers.BigNumber.from("0"),
    },
    extra: {
        dataHash: ethers.constants.HashZero,
        l1SignalRoot: ethers.constants.HashZero,
        l2SignalRoot: ethers.constants.HashZero,
        l1BlockHash: ethers.constants.HashZero,
        l1BlockHeight: ethers.BigNumber.from("0"),
        proposedAt: ethers.BigNumber.from("0"),
        validator: ethers.constants.AddressZero,
        blocktimeTarget: ethers.BigNumber.from("0"),
    },
    headerHash: process.env.GENESIS_HEADER_HASH
        ? process.env.GENESIS_HEADER_HASH
        : "0x94d9dc3c7a055e5f9a643fa6b9a5d6361102c33515de975f2e5646b2edee6cf1",
    parentHash: ethers.constants.HashZero,
    validatorSig: [],
}
