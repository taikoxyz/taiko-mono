import { task } from "hardhat/config"
import * as types from "hardhat/internal/core/params/argumentTypes"
import * as config from "./config"
import * as log from "./log"
import * as utils from "./utils"

task("deploy_L1")
    .addOptionalParam(
        "confirmations",
        "Number of confirmations to wait for deploy transaction.",
        config.DEFAULT_DEPLOY_CONFIRMATIONS,
        types.int
    )
    .setAction(async (args, hre: any) => {
        if (
            hre.network.name === "localhost" ||
            hre.network.name === "hardhat"
        ) {
            args.confirmations = 1
        } else if (
            hre.network.name === "ropsten" ||
            hre.network.name === "goerli"
        ) {
            args.confirmations = 6
        }

        hre.args = args
        await deployContracts(hre)
    })

export async function deployContracts(hre: any) {
    const ethers = hre.ethers
    const network = hre.network.name
    const { chainId } = await hre.ethers.provider.getNetwork()
    const deployer = await utils.getDeployer(hre)
    const l2GenesisBlockHash =
        process.env.L2_GENESIS_BLOCK_HASH || ethers.constants.HashZero
    const l2GenesisStateRoot =
        process.env.L2_GENESIS_STATE_ROOT || ethers.constants.HashZero

    log.debug(`network: ${network}`)
    log.debug(`chainId: ${chainId}`)
    log.debug(`deployer: ${deployer}`)
    log.debug(`L2_GENESIS_BLOCK_HASH: ${l2GenesisBlockHash}`)
    log.debug(`L2_GENESIS_STATE_ROOT: ${l2GenesisStateRoot}`)
    log.debug(`confirmations: ${hre.args.confirmations}`)
    log.debug()

    const { KeyManager, LibZKP, LibMerkleProof, LibTxList } =
        await deployBaseLibs(hre)

    // deploy TaikoL1 and init
    const taikoL1 = await utils.deployContract(hre, "TaikoL1", {
        LibZKP,
        LibMerkleProof,
        LibTxList,
    })

    await utils.waitTx(
        hre,
        await taikoL1.init(
            {
                blockHash: l2GenesisBlockHash,
                stateRoot: l2GenesisStateRoot,
            },
            KeyManager
        )
    )

    // save deployments
    const deployments = {
        network: network,
        chainId: chainId,
        deployer: deployer,
        l2GenesisStateRoot,
        contracts: Object.assign({ KeyManager }, { TaikoL1: taikoL1.address }),
    }

    utils.saveDeployments(`${network}_L1`, deployments)

    return deployments
}

async function deployBaseLibs(hre: any) {
    const keyManager = await utils.deployContract(hre, "KeyManager")
    await utils.waitTx(hre, await keyManager.init())

    const libZKP = await utils.deployContract(hre, "LibZKP")
    const libMerkleProof = await utils.deployContract(hre, "LibMerkleProof")
    const libTxList = await utils.deployContract(hre, "LibTxList")

    return {
        KeyManager: keyManager.address,
        LibZKP: libZKP.address,
        LibMerkleProof: libMerkleProof.address,
        LibTxList: libTxList.address,
    }
}
