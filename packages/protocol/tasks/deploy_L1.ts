import * as ethers from "ethers";
import { task } from "hardhat/config";
import * as types from "hardhat/internal/core/params/argumentTypes";
import * as config from "./config";
import * as log from "./log";
import * as utils from "./utils";

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
    .addOptionalParam("l2ChainId", "L2 chain id", config.K_CHAIN_ID, types.int)
    .addOptionalParam(
        "bridgeFunderPrivateKey",
        "Private key of the L1 bridge funder",
        "",
        types.string
    )
    .addOptionalParam(
        "bridgeFund",
        "L1 bridge's initial fund in hex",
        "",
        types.string
    )
    .addOptionalParam(
        "oracleProver",
        "Address of the oracle prover",
        "",
        types.string
    )
    .addOptionalParam(
        "soloProposer",
        "Address of the solo proposer",
        "",
        types.string
    )
    .addOptionalParam(
        "confirmations",
        "Number of confirmations to wait for deploy transaction.",
        config.K_DEPLOY_CONFIRMATIONS,
        types.int
    )
    .setAction(async (args, hre: any) => {
        if (
            hre.network.name === "localhost" ||
            hre.network.name === "hardhat"
        ) {
            args.confirmations = 1;
        } else if (
            hre.network.name === "ropsten" ||
            hre.network.name === "goerli"
        ) {
            args.confirmations = 6;
        }

        hre.args = args;
        await deployContracts(hre);
    });

export async function deployContracts(hre: any) {
    const network = hre.network.name;
    const { chainId } = await hre.ethers.provider.getNetwork();
    const deployer = await utils.getDeployer(hre);
    const daoVault = hre.args.daoVault;
    const teamVault = hre.args.teamVault;
    const l2GenesisBlockHash = hre.args.l2GenesisBlockHash;
    const taikoL2Address = hre.args.taikoL2;
    const l2ChainId = hre.args.l2ChainId;
    const bridgeFunderPrivateKey = hre.args.bridgeFunderPrivateKey;
    const bridgeFund = hre.args.bridgeFund;
    const oracleProver = hre.args.oracleProver;
    const soloProposer = hre.args.soloProposer;

    log.debug(`network: ${network}`);
    log.debug(`chainId: ${chainId}`);
    log.debug(`deployer: ${deployer}`);
    log.debug(`daoVault: ${daoVault}`);
    log.debug(`l2GenesisBlockHash: ${l2GenesisBlockHash}`);
    log.debug(`taikoL2Address: ${taikoL2Address}`);
    log.debug(`l2ChainId: ${l2ChainId}`);
    log.debug(`bridgeFunderPrivateKey: ${bridgeFunderPrivateKey}`);
    log.debug(`bridgeFund: ${bridgeFund}`);
    log.debug(`oracleProver: ${oracleProver}`);
    log.debug(`soloProposer: ${soloProposer}`);
    log.debug(`confirmations: ${hre.args.confirmations}`);
    log.debug();

    // AddressManager
    const AddressManager = await utils.deployContract(hre, "AddressManager");
    await utils.waitTx(hre, await AddressManager.init());

    const ProofVerifier = await utils.deployContract(hre, "ProofVerifier");
    await utils.waitTx(hre, await ProofVerifier.init(AddressManager.address));
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(
            `${chainId}.proof_verifier`,
            ProofVerifier.address
        )
    );

    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${chainId}.dao_vault`, daoVault)
    );
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${chainId}.team_vault`, teamVault)
    );
    // Used by LibProving
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${l2ChainId}.taiko`, taikoL2Address)
    );

    // TaikoToken
    const TaikoToken = await utils.deployContract(hre, "TaikoToken");
    await utils.waitTx(
        hre,
        await TaikoToken.init(
            "Test Taiko Token",
            "TTKO",
            AddressManager.address
        )
    );
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(
            `${chainId}.tko_token`,
            TaikoToken.address
        )
    );

    // HorseToken
    const HorseToken = await utils.deployContract(hre, "FreeMintERC20", {}, [
        "Horse Token",
        "HORSE",
    ]);

    // BullToken
    const BullToken = await utils.deployContract(
        hre,
        "MayFailFreeMintERC20",
        {},
        ["Bull Token", "BLL"]
    );

    // TaikoL1
    const TaikoL1 = await utils.deployContract(
        hre,
        "TaikoL1",
        await deployBaseLibs(hre)
    );

    const feeBase = hre.ethers.BigNumber.from(10).pow(18);

    await utils.waitTx(
        hre,
        await TaikoL1.init(AddressManager.address, l2GenesisBlockHash, feeBase)
    );

    // Used by LibBridgeRead
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${chainId}.taiko`, TaikoL1.address)
    );

    // Used by TaikoToken
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(
            `${chainId}.proto_broker`,
            TaikoL1.address
        )
    );

    // Bridge
    const Bridge = await deployBridge(hre, AddressManager.address);

    // TokenVault
    const TokenVault = await deployTokenVault(hre, AddressManager.address);

    // Used by TokenVault
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(`${chainId}.bridge`, Bridge.address)
    );

    // Fund L1 bridge, which is necessary when there is a L2 faucet
    if (
        bridgeFunderPrivateKey.length &&
        hre.ethers.utils.isHexString(bridgeFund)
    ) {
        const funder = new hre.ethers.Wallet(
            bridgeFunderPrivateKey,
            hre.ethers.provider
        );

        await utils.waitTx(
            hre,
            await funder.sendTransaction({
                to: Bridge.address,
                value: hre.ethers.BigNumber.from(bridgeFund),
            })
        );

        log.debug(
            `L1 bridge balance: ${hre.ethers.utils.hexlify(
                await hre.ethers.provider.getBalance(Bridge.address)
            )}`
        );
    }

    // SignalService
    const SignalService = await deploySignalService(
        hre,
        AddressManager.address
    );

    // Used by Bridge
    await utils.waitTx(
        hre,
        await AddressManager.setAddress(
            `${chainId}.signal_service`,
            SignalService.address
        )
    );

    // PlonkVerifier
    const PlonkVerifiers = await deployPlonkVerifiers(hre);

    // Used by ProofVerifier
    for (let i = 0; i < PlonkVerifiers.length; i++) {
        await utils.waitTx(
            hre,
            await AddressManager.setAddress(
                // string(abi.encodePacked("plonk_verifier_", i))
                `${chainId}.${Buffer.from(
                    ethers.utils.arrayify(
                        ethers.utils.solidityPack(
                            ["string", "uint16"],
                            ["plonk_verifier_", i]
                        )
                    )
                ).toString()}`,
                PlonkVerifiers[i].address
            )
        );
    }

    if (ethers.utils.isAddress(oracleProver)) {
        await utils.waitTx(
            hre,
            await AddressManager.setAddress(
                `${chainId}.oracle_prover`,
                oracleProver
            )
        );
    }

    if (ethers.utils.isAddress(soloProposer)) {
        await utils.waitTx(
            hre,
            await AddressManager.setAddress(
                `${chainId}.solo_proposer`,
                soloProposer
            )
        );
    }

    // save deployments
    const deployments = {
        network,
        chainId,
        deployer,
        l2GenesisBlockHash,
        contracts: Object.assign(
            { AddressManager: AddressManager.address },
            { TaikoToken: TaikoToken.address },
            { TaikoL1: TaikoL1.address },
            { Bridge: Bridge.address },
            { SignalService: SignalService.address },
            { TokenVault: TokenVault.address },
            { BullToken: BullToken.address },
            { HorseToken: HorseToken.address }
        ),
    };

    utils.saveDeployments(`${network}_L1`, deployments);

    return deployments;
}

async function deployBaseLibs(hre: any) {
    const libReceiptDecoder = await utils.deployContract(
        hre,
        "LibReceiptDecoder"
    );
    const libTxDecoder = await utils.deployContract(hre, "LibTxDecoder");

    const libVerifying = await utils.deployContract(hre, "LibVerifying", {});
    const libProposing = await utils.deployContract(hre, "LibProposing", {});

    const libProving = await utils.deployContract(hre, "LibProving", {
        LibReceiptDecoder: libReceiptDecoder.address,
        LibTxDecoder: libTxDecoder.address,
    });

    return {
        LibVerifying: libVerifying.address,
        LibProposing: libProposing.address,
        LibProving: libProving.address,
    };
}

async function deployBridge(hre: any, addressManager: string): Promise<any> {
    const libTrieProof = await utils.deployContract(hre, "LibTrieProof");
    const libBridgeRetry = await utils.deployContract(hre, "LibBridgeRetry");
    const libBridgeProcess = await utils.deployContract(
        hre,
        "LibBridgeProcess"
    );

    const Bridge = await utils.deployContract(hre, "Bridge", {
        LibTrieProof: libTrieProof.address,
        LibBridgeRetry: libBridgeRetry.address,
        LibBridgeProcess: libBridgeProcess.address,
    });

    await utils.waitTx(hre, await Bridge.init(addressManager));

    return Bridge;
}

async function deployTokenVault(
    hre: any,
    addressManager: string
): Promise<any> {
    const TokenVault = await utils.deployContract(hre, "TokenVault");

    await utils.waitTx(hre, await TokenVault.init(addressManager));

    return TokenVault;
}

async function deploySignalService(
    hre: any,
    addressManager: string
): Promise<any> {
    const libTrieProof = await utils.deployContract(hre, "LibTrieProof");

    const SignalService = await utils.deployContract(hre, "SignalService", {
        LibTrieProof: libTrieProof.address,
    });

    await utils.waitTx(hre, await SignalService.init(addressManager));

    return SignalService;
}

async function deployPlonkVerifiers(hre: any): Promise<any> {
    const PlonkVerifier10TxsByteCode = utils.compileYulContract(
        "../contracts/libs/yul/PlonkVerifier_10_txs.yulp"
    );
    const PlonkVerifier80TxsByteCode = utils.compileYulContract(
        "../contracts/libs/yul/PlonkVerifier_80_txs.yulp"
    );

    return [
        {
            address: await utils.deployBytecode(
                hre,
                PlonkVerifier10TxsByteCode,
                "PlonkVerifier_10_txs"
            ),
        },
        {
            address: await utils.deployBytecode(
                hre,
                PlonkVerifier80TxsByteCode,
                "PlonkVerifier_80_txs"
            ),
        },
    ];
}
