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
        "v1TaikoL2",
        "The V1TaikoL2 address",
        ethers.constants.AddressZero
    )
    .addOptionalParam(
        "l2GenesisBlockHash",
        "L2 genesis block hash",
        ethers.constants.HashZero
    )
    .addOptionalParam(
        "l2ChainId",
        "L2 chain id",
        config.TAIKO_CHAINID,
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
    const v1TaikoL2Address = hre.args.v1TaikoL2
    const l2ChainId = hre.args.l2ChainId

    log.debug(`network: ${network}`)
    log.debug(`chainId: ${chainId}`)
    log.debug(`deployer: ${deployer}`)
    log.debug(`daoVault: ${daoVault}`)
    log.debug(`l2GenesisBlockHash: ${l2GenesisBlockHash}`)
    log.debug(`v1TaikoL2Address: ${v1TaikoL2Address}`)
    log.debug(`l2ChainId: ${l2ChainId}`)
    log.debug(`confirmations: ${hre.args.confirmations}`)
    log.debug()

    // AddressManager
    const AddressManager = await utils.deployContract(hre, "AddressManager")
    await utils.waitTx(hre, await AddressManager.init())
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${chainId}.dao_vault`, daoVault)
    )
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${chainId}.team_vault`, teamVault)
    )
    // Used by V1Proving
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${l2ChainId}.taiko`, v1TaikoL2Address)
    )

    // TkoToken
    const TkoToken = await utils.deployContract(hre, "TkoToken")
    await utils.waitTx(hre, await TkoToken.init(AddressManager.address))
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(
            `${chainId}.tko_token`,
            TkoToken.address
        )
    )

    // Config manager
    const ConfigManager = await utils.deployContract(hre, "ConfigManager")
    await utils.waitTx(hre, await ConfigManager.init())
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(
            `${chainId}.config_manager`,
            ConfigManager.address
        )
    )

    // TaikoL1
    const TaikoL1 = await utils.deployContract(
        hre,
        "TaikoL1",
        await deployBaseLibs(hre)
    )
    const avgFee = hre.ethers.BigNumber.from(10).pow(18)

    await utils.waitTx(
        hre,
        await TaikoL1.init(AddressManager.address, l2GenesisBlockHash, avgFee)
    )

    // Used by LibBridgeRead
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${chainId}.taiko`, TaikoL1.address)
    )

    // Bridge
    const Bridge = await deployBridge(hre, AddressManager.address)

    // TokenVault
    const TokenVault = await deployTokenVault(hre, AddressManager.address)

    // Used by TokenVault
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${chainId}.bridge`, Bridge.address)
    )

    // save deployments
    const deployments = {
        network,
        chainId,
        deployer,
        l2GenesisBlockHash,
        contracts: Object.assign(
            { AddressManager: AddressManager.address },
            { TkoToken: TkoToken.address },
            { TaikoL1: TaikoL1.address },
            { Bridge: Bridge.address },
            { TokenVault: TokenVault.address }
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
    const libUint512 = await utils.deployContract(hre, "Uint512")

    const v1Utils = await utils.deployContract(hre, "V1Utils")
    const v1Finalizing = await utils.deployContract(hre, "V1Finalizing", {
        V1Utils: v1Utils.address,
    })
    const v1Proposing = await utils.deployContract(hre, "V1Proposing", {
        V1Utils: v1Utils.address,
    })
    const v1Proving = await utils.deployContract(hre, "V1Proving", {
        LibZKP: libZKP.address,
        LibReceiptDecoder: libReceiptDecoder.address,
        LibTxDecoder: libTxDecoder.address,
        Uint512: libUint512.address,
    })

    return {
        V1Finalizing: v1Finalizing.address,
        V1Proposing: v1Proposing.address,
        V1Proving: v1Proving.address,
        Uint512: libUint512.address,
    }
}

async function deployBridge(hre: any, addressManager: string): Promise<any> {
    const libTrieProof = await utils.deployContract(hre, "LibTrieProof")
    const libBridgeRetry = await utils.deployContract(hre, "LibBridgeRetry")
    const libBridgeProcess = await utils.deployContract(
        hre,
        "LibBridgeProcess",
        {
            LibTrieProof: libTrieProof.address,
        }
    )

    const Bridge = await utils.deployContract(hre, "Bridge", {
        LibTrieProof: libTrieProof.address,
        LibBridgeRetry: libBridgeRetry.address,
        LibBridgeProcess: libBridgeProcess.address,
    })

    await utils.waitTx(hre, await Bridge.init(addressManager))

    return Bridge
}

async function deployTokenVault(
    hre: any,
    addressManager: string
): Promise<any> {
    const TokenVault = await utils.deployContract(hre, "TokenVault")

    await utils.waitTx(hre, await TokenVault.init(addressManager))

    return TokenVault
}
