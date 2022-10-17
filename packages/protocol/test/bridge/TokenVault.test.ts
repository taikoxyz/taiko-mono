import { expect } from "chai"
import { AddressManager, TokenVault } from "../../typechain"
import { ethers } from "hardhat"
import { BigNumber, BigNumberish } from "ethers"

type CanonicalERC20 = {
    chainId: BigNumberish
    addr: string
    decimals: BigNumberish
    symbol: string
    name: string
}

const weth: CanonicalERC20 = {
    chainId: 5,
    addr: "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
    decimals: 18,
    symbol: "WETH",
    name: "Wrapped Ether",
}

describe("TokenVault", function () {
    async function deployTokenVaultFixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        // Deploying addressManager Contract
        const tokenVaultAddressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await tokenVaultAddressManager.init()

        const TokenVaultFactory = await ethers.getContractFactory("TokenVault")

        const tokenVault: TokenVault = await TokenVaultFactory.connect(
            owner
        ).deploy()

        await tokenVault.init(tokenVaultAddressManager.address)

        return {
            owner,
            nonOwner,
            tokenVault,
            tokenVaultAddressManager,
        }
    }

    describe("receiveERC20()", async () => {
        it("throws when named 'bridge' is not the caller", async () => {
            const { owner, nonOwner, tokenVault } =
                await deployTokenVaultFixture()
            const amount = BigNumber.from(1)

            await expect(
                tokenVault.receiveERC20(
                    weth,
                    owner.address,
                    nonOwner.address,
                    amount
                )
            ).to.be.revertedWith("AR:denied")
        })
    })
})
