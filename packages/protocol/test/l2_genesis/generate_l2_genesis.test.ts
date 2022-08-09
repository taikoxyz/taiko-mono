import { expect } from "chai"
import * as hre from "hardhat"

const ethers = hre.ethers
const action = process.env.TEST_L2_GENESIS ? describe : describe.skip

action("Generate L2 Genesis", function () {
    let alloc: any = null

    if (process.env.TEST_L2_GENESIS) {
        alloc = require("../../deployments/l2_genesis_alloc.json")
    }

    const provider = new hre.ethers.providers.JsonRpcProvider(
        "http://localhost:18545"
    )

    const signer = new hre.ethers.Wallet(
        "2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501200",
        provider
    )

    const testConfig = require("./test_config")

    const premintEthAccounts = testConfig.premintEthAccounts

    before(async () => {
        let retry = 0

        while (true) {
            try {
                const network = await provider.getNetwork()
                if (network.chainId) break
            } catch (_) {}

            if (++retry > 10) {
                throw new Error("geth initializing timeout")
            }

            await sleep(1000)
        }

        console.log("geth initialized")
    })

    it("contracts should be deployed", async function () {
        for (const address of Object.keys(alloc)) {
            if (
                premintEthAccounts
                    .map((premintEthAccount: any) => {
                        const accountAddress = Object.keys(premintEthAccount)[0]
                        return accountAddress
                    })
                    .includes(address)
            ) {
                continue
            }
            const code: string = await provider.getCode(address)
            const expectCode: string = alloc[address].code

            expect(code.toLowerCase()).to.be.equal(expectCode.toLowerCase())
        }
    })

    it("premint ETH should be allocated", async function () {
        let bridgeBalance = hre.ethers.BigNumber.from("2").pow(128).sub(1) // MaxUint128

        for (const premintEthAccount of premintEthAccounts) {
            const accountAddress = Object.keys(premintEthAccount)[0]
            const balance = hre.ethers.utils.parseEther(
                `${Object.values(premintEthAccount)[0]}`
            )
            expect(await provider.getBalance(accountAddress)).to.be.equal(
                balance.toHexString()
            )

            bridgeBalance = bridgeBalance.sub(balance)
        }

        // NOTE: since L2 bridge contract hasn't finished yet, temporarily move
        // L2 bridge's balance to TaikoL2 contract address.
        const bridgeAddress = getContractAlloc("TaikoL2").address

        expect(await provider.getBalance(bridgeAddress)).to.be.equal(
            bridgeBalance.toHexString()
        )
    })

    describe("contracts can be called normally", function () {
        it("AddressManager", async function () {
            const addressManagerAlloc = getContractAlloc("AddressManager")

            const addressManager = new hre.ethers.Contract(
                addressManagerAlloc.address,
                require("../../artifacts/contracts/thirdparty/AddressManager.sol/AddressManager.json").abi,
                provider
            )

            const owner = await addressManager.owner()

            expect(owner).to.be.equal(testConfig.contractOwner)

            const ethDepositor = await addressManager.getAddress(
                "eth_depositor"
            )

            expect(ethDepositor).to.be.equal(testConfig.ethDepositor)
        })

        it("LibTxListValidator", async function () {
            const LibTxListValidatorAlloc =
                getContractAlloc("LibTxListValidator")

            const LibTxListValidator = new hre.ethers.Contract(
                LibTxListValidatorAlloc.address,
                require("../../artifacts/contracts/libs/LibTxListValidator.sol/LibTxListValidator.json").abi,
                signer
            )

            const gasLimit =
                await LibTxListValidator.MAX_TAIKO_BLOCK_GAS_LIMIT()

            expect(gasLimit.gt(ethers.BigNumber.from(0))).to.be.equal(true)
        })

        it("TaikoL2", async function () {
            const TaikoL2Alloc = getContractAlloc("TaikoL2")

            const TaikoL2 = new hre.ethers.Contract(
                TaikoL2Alloc.address,
                require("../../artifacts/contracts/L2/TaikoL2.sol/TaikoL2.json").abi,
                signer
            )

            const anchorHeight = 1
            const anchorHash = ethers.utils.hexlify(
                ethers.utils.randomBytes(32)
            )

            await expect(TaikoL2.anchor(anchorHeight, anchorHash)).to.emit(
                TaikoL2,
                "Anchored"
            )

            await expect(
                TaikoL2.creditEther(hre.ethers.constants.AddressZero, 1024)
            ).to.emit(TaikoL2, "EtherCredited")
        })
    })

    function getContractAlloc(name: string): any {
        for (const address of Object.keys(alloc)) {
            if (alloc[address].contractName === name) {
                return Object.assign(alloc[address], { address })
            }
        }

        throw new Error(`contract alloc: ${name} not found`)
    }
})

function sleep(ms: number) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms)
    })
}
