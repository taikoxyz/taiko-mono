// eslint-disable-next-line import/no-named-default
import { default as hre, ethers } from "hardhat"

const action = process.env.TEST_LIB_MERKLE_PROOF ? describe : describe.skip

action("LibReceiptDecoder", function () {
    let libReceiptDecoder: any

    before(async function () {
        const baseLibReceiptDecoder = await (
            await ethers.getContractFactory("LibReceiptDecoder")
        ).deploy()

        libReceiptDecoder = await (
            await ethers.getContractFactory("TestLibReceiptDecoder", {
                libraries: {
                    LibReceiptDecoder: baseLibReceiptDecoder.address,
                },
            })
        ).deploy()
    })

    it("should decode RLP encoded transaction receipts", async function () {
        const tx = await libReceiptDecoder.emitTestEvent(
            randomBigInt(),
            ethers.utils.randomBytes(32)
        )

        console.log({ tx })

        const receipt = await tx.wait()

        console.log({ receipt })

        const rawReceipt = await hre.network.provider.send(
            "debug_getRawReceipts",
            [tx.blockHash]
        )

        console.log({ rawReceipt })
    })

    function randomBigInt() {
        return ethers.BigNumber.from(ethers.utils.randomBytes(32))
    }
})
