import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("V1TaikoL2", function () {
    let v1TaikoL2: any
    let addressManager: any
    let signers: any

    before(async function () {
        // Deploying addressManager Contract
        addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        // Deploying V1TaikoL2 Contract linked with LibTxDecoder (throws error otherwise)
        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy()

        const { chainId } = await hre.ethers.provider.getNetwork()

        const v1TaikoL2Factory = await ethers.getContractFactory("V1TaikoL2", {
            libraries: {
                LibTxDecoder: libTxDecoder.address,
            },
        })
        v1TaikoL2 = await v1TaikoL2Factory.deploy(
            addressManager.address,
            chainId
        )

        signers = await ethers.getSigners()
        await addressManager.setAddress(
            "eth_depositor",
            await signers[0].getAddress()
        )
    })

    it("should emit EtherReturned event when receiving ether", async function () {
        expect(
            await signers[0].sendTransaction({
                to: v1TaikoL2.address,
                value: ethers.utils.parseEther("150.0"),
            })
        ).to.emit(v1TaikoL2, "EtherReturned")
    })

    describe("creditEther()", async function () {
        it("should throw if recipient address is v1TaikoL2.address", async function () {
            await expect(v1TaikoL2.creditEther(v1TaikoL2.address, "1000")).to
                .reverted
        })

        it('should revert if not from named "eth_depositor"', async function () {
            const randWallet = ethers.Wallet.createRandom().address
            await expect(
                v1TaikoL2.connect(randWallet).creditEther(randWallet, "1000")
            ).to.reverted
        })

        it("should emit EtherCredited when crediting Ether to recipient and balance of reciever should be ether credited", async function () {
            const recieverWallet = ethers.Wallet.createRandom().address
            const amount = "10000"
            expect(await v1TaikoL2.creditEther(recieverWallet, amount)).to.emit(
                v1TaikoL2,
                "EtherCredited"
            )
            expect(await ethers.provider.getBalance(recieverWallet)).to.equal(
                amount
            )
        })
    })
})
