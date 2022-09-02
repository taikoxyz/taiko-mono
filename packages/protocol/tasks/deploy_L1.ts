import * as ethers from "ethers"
import { task } from "hardhat/config"
import * as types from "hardhat/internal/core/params/argumentTypes"
import * as config from "./config"
import * as log from "./log"
import * as utils from "./utils"

task("deploy_L1")
    .addParam("daoVault", "The DAO vault address")
    .addParam("teamVault", "The team vault address")
    .addOptionalParam(
        "taikoL2",
        "The TaikoL2 address",
        ethers.constants.AddressZero
    )
    .addOptionalParam(
        "l2GenesisBlockHash",
        "L2 genesis block hash",
        ethers.constants.HashZero
    )
    .addOptionalParam(
        "gasPriceNow",
        "The initialization parameter `_gasPriceNow` of TaikoProtoBroker",
        0,
        types.int
    )
    .addOptionalParam(
        "amountToMintToDAOThreshold",
        "The initialization parameter `_amountToMintToDAOThreshold` of TaikoProtoBroker",
        1,
        types.int
    )
    .addOptionalParam(
        "amountMintToDAO",
        "The initialization parameter `_amountMintToDAO` of TaikoProtoBroker",
        0,
        types.int
    )
    .addOptionalParam(
        "amountMintToTeam",
        "The initialization parameter `_amountMintToTeam` of TaikoProtoBroker",
        0,
        types.int
    )
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
    const network = hre.network.name
    const { chainId } = await hre.ethers.provider.getNetwork()
    const deployer = await utils.getDeployer(hre)
    const daoVault = hre.args.daoVault
    const teamVault = hre.args.teamVault
    const l2GenesisBlockHash = hre.args.l2GenesisBlockHash
    const taikoL2Address = hre.args.taikoL2
    // Initialization parameters of TaikoProtoBroker
    const gasPriceNow = hre.args.gasPriceNow
    const amountToMintToDAOThreshold = hre.args.amountToMintToDAOThreshold
    const amountMintToDAO = hre.args.amountMintToDAO
    const amountMintToTeam = hre.args.amountMintToTeam

    log.debug(`network: ${network}`)
    log.debug(`chainId: ${chainId}`)
    log.debug(`deployer: ${deployer}`)
    log.debug(`daoVault: ${daoVault}`)
    log.debug(`l2GenesisBlockHash: ${l2GenesisBlockHash}`)
    log.debug(`taikoL2Address: ${taikoL2Address}`)
    log.debug(`gasPriceNow: ${gasPriceNow}`)
    log.debug(`amountToMintToDAOThreshold: ${amountToMintToDAOThreshold}`)
    log.debug(`amountMintToDAO: ${amountMintToDAO}`)
    log.debug(`amountMintToTeam: ${amountMintToTeam}`)
    log.debug(`confirmations: ${hre.args.confirmations}`)
    log.debug()

    // AddressManager
    const AddressManager = await utils.deployContract(hre, "AddressManager")
    await utils.waitTx(hre, await AddressManager.init())
    await utils.waitTx(
        hre,
        await AddressManager.setAddress("dao_vault", daoVault)
    )
    await utils.waitTx(
        hre,
        await AddressManager.setAddress("team_vault", teamVault)
    )
    await utils.waitTx(
        hre,
        await AddressManager.setAddress("taiko_l2", taikoL2Address)
    )

    // TaiToken
    const TaiToken = await utils.deployContract(hre, "TaiToken")
    await utils.waitTx(hre, await TaiToken.init(AddressManager.address))
    await utils.waitTx(
        hre,
        await AddressManager.setAddress("tai_token", TaiToken.address)
    )

    // Proto Broker
    const ProtoBroker = await utils.deployContract(hre, "TaikoProtoBroker")
    await utils.waitTx(
        hre,
        await AddressManager.setAddress("proto_broker", ProtoBroker.address)
    )
    await utils.waitTx(
        hre,
        await ProtoBroker.init(
            AddressManager.address,
            gasPriceNow,
            amountToMintToDAOThreshold,
            amountMintToDAO,
            amountMintToTeam
        )
    )

    // Config manager
    const ConfigManager = await utils.deployContract(hre, "ConfigManager")
    await utils.waitTx(hre, await ConfigManager.init())
    await utils.waitTx(
        hre,
        await AddressManager.setAddress("config_manager", ConfigManager.address)
    )

    // TaikoL1
    const taikoL1 = await utils.deployContract(
        hre,
        "TaikoL1",
        await deployBaseLibs(hre)
    )
    await utils.waitTx(
        hre,
        await taikoL1.init(AddressManager.address, l2GenesisBlockHash)
    )

    // save deployments
    const deployments = {
        network: network,
        chainId: chainId,
        deployer: deployer,
        l2GenesisBlockHash,
        contracts: Object.assign(
            { AddressManager: AddressManager.address },
            { TaiToken: TaiToken.address },
            { ProtoBroker: ProtoBroker.address },
            { TaikoL1: taikoL1.address }
        ),
    }

    utils.saveDeployments(`${network}_L1`, deployments)

    return deployments
}

async function deployBaseLibs(hre: any) {
    const libZKP = await utils.deployContract(hre, "LibZKP")
    const libReceiptDecoder = await utils.deployContract(
        hre,
        "LibReceiptDecoder"
    )
    const libTxDecoder = await utils.deployContract(hre, "LibTxDecoder")

    return {
        LibZKP: libZKP.address,
        LibReceiptDecoder: libReceiptDecoder.address,
        LibTxDecoder: libTxDecoder.address,
    }
}
