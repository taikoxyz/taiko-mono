import { expect } from "chai"
import { AddressManager, BridgedERC20 } from "../../typechain"
import { ethers } from "hardhat"

const WETH_GOERLI = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"
describe("BridgedERC20", function () {
    async function deployBridgedERC20Fixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        // Deploying addressManager Contract
        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const BridgedERC20Factory = await ethers.getContractFactory(
            "BridgedERC20"
        )

        const erc20: BridgedERC20 = await BridgedERC20Factory.connect(
            owner
        ).deploy()

        return {
            owner,
            nonOwner,
            addressManager,
            erc20,
        }
    }

    describe("init()", function () {
        it("inits when srctoken is not 0, srcChainId is not 0, srcChainId is not the current blocks chain id, symbol is not 0 length, name is not 0 length", async () => {
            const { owner, erc20, addressManager } =
                await deployBridgedERC20Fixture()

            await expect(
                erc20
                    .connect(owner)
                    .init(
                        addressManager.address,
                        WETH_GOERLI,
                        5,
                        18,
                        "SYMB",
                        "Name"
                    )
            ).not.to.be.revertedWith("BE:params")
        })
        it("throws when srcToken is address 0 ", async () => {
            const { owner, erc20, addressManager } =
                await deployBridgedERC20Fixture()

            await expect(
                erc20
                    .connect(owner)
                    .init(
                        addressManager.address,
                        ethers.constants.AddressZero,
                        5,
                        18,
                        "SYMB",
                        "Name"
                    )
            ).to.be.revertedWith("BE:params")
        })
    })
})
