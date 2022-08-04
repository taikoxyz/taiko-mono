// eslint-disable-next-line no-unused-vars
import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers
// const EBN = ethers.BigNumber

describe("Lib_BlockHeaderDecoder", async function () {
    // eslint-disable-next-line no-unused-vars
    let blockHeaderDecoder: any
    let blockHash: any
    let blockHeader: any
    let headerStateRoot: any
    let headerTimeStamp: any

    before(async function () {
        // Deploying Lib to Link
        const blkHdrDcdrLib = await (
            await ethers.getContractFactory("Lib_BlockHeaderDecoder")
        ).deploy()

        // Deploying Library
        blockHeaderDecoder = await (
            await ethers.getContractFactory("TestLibBlockHeaderDecoder", {
                libraries: {
                    Lib_BlockHeaderDecoder: blkHdrDcdrLib.address,
                },
            })
        ).deploy()

        // Defining test block header and hash
    })

    it("Decode should return stateRoot and timeStamp", async function () {
        // console.log(await ethers.utils.isBytesLike(blockHeader))
        expect(
            await blockHeaderDecoder.decodeBlockHeader(
                await ethers.utils.RLP.encode(blockHeader),
                blockHash
            )
        ).to.equal({ headerStateRoot, headerTimeStamp })
    })
})
