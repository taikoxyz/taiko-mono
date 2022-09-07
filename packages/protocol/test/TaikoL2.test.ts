import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("TaikoL2", function () {
    let taikoL2: any
    let addressManager: any
    let signers: any

    function randomBytes32() {
        return ethers.utils.hexlify(ethers.utils.randomBytes(32))
    }

    before(async function () {
        // Deploying addressManager Contract
        addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        // Deploying TaikoL2 Contract linked with LibTxDecoder (throws error otherwise)
        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy()

        const taikoL2Factory = await ethers.getContractFactory("TaikoL2", {
            libraries: {
                LibTxDecoder: libTxDecoder.address,
            },
        })
        taikoL2 = await taikoL2Factory.deploy()

        const { chainId } = await hre.ethers.provider.getNetwork()
        await taikoL2.init(addressManager.address, chainId)

        signers = await ethers.getSigners()
        await addressManager.setAddress(
            "eth_depositor",
            await signers[0].getAddress()
        )
    })

    it("should emit EtherReturned event when receiving ether", async function () {
        expect(
            await signers[0].sendTransaction({
                to: taikoL2.address,
                value: ethers.utils.parseEther("150.0"),
            })
        ).to.emit(taikoL2, "EtherReturned")
    })

    describe("creditEther()", async function () {
        it("should throw if recipient address is taikoL2.address", async function () {
            await expect(taikoL2.creditEther(taikoL2.address, "1000")).to
                .reverted
        })

        it('should revert if not from named "eth_depositor"', async function () {
            const randWallet = ethers.Wallet.createRandom().address
            await expect(
                taikoL2.connect(randWallet).creditEther(randWallet, "1000")
            ).to.reverted
        })

        it("should emit EtherCredited when crediting Ether to recipient and balance of reciever should be ether credited", async function () {
            const recieverWallet = ethers.Wallet.createRandom().address
            const amount = "10000"
            expect(await taikoL2.creditEther(recieverWallet, amount)).to.emit(
                taikoL2,
                "EtherCredited"
            )
            expect(await ethers.provider.getBalance(recieverWallet)).to.equal(
                amount
            )
        })
    })

    describe("anchor()", async function () {
        it("should revert since ancestor hashes not written", async function () {
            const randomHash = randomBytes32()
            await expect(taikoL2.anchor(10, randomHash)).to.be.revertedWith(
                "L2:anchored"
            )
        })
    })
})
