import * as childProcess from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as log from "./log";

async function deployContract(
    hre: any,
    contractName: string,
    libraries = {},
    args: any[] = [],
    overrides = {}
) {
    const contractArgs = args || [];
    const contractArtifacts = await hre.ethers.getContractFactory(
        contractName,
        {
            libraries: libraries,
        }
    );

    const deployed = await contractArtifacts.deploy(...contractArgs, overrides);
    log.debug(
        `${contractName} deploying, tx ${deployed.deployTransaction.hash}, waiting for confirmations`
    );

    await deployed.deployed();

    log.debug(`${contractName} deployed at ${deployed.address}`);
    return deployed;
}

function compileYulContract(contractPath: string): string {
    const SOLC_COMMAND = path.join(__dirname, "../bin/solc");

    if (!fs.existsSync(SOLC_COMMAND)) {
        throw new Error(
            `sloc command not found in ${SOLC_COMMAND}, please run "./scripts/download_solc.sh".`
        );
    }

    if (!path.isAbsolute(contractPath)) {
        contractPath = path.join(__dirname, contractPath);
    }

    const compile = childProcess.spawnSync(SOLC_COMMAND, [
        "--yul",
        "--bin",
        contractPath,
    ]);

    let isNextLineByteCode = false;
    let byteCode = null;
    for (const line of compile.stdout.toString().split("\n")) {
        if (isNextLineByteCode) {
            byteCode = line;
            break;
        }

        if (line.includes("Binary representation:")) {
            isNextLineByteCode = true;
        }
    }

    if (!byteCode) {
        throw new Error(
            `failed to compile PlonkVerifier, sloc: ${SOLC_COMMAND}, contract: ${contractPath}`
        );
    }

    log.debug(
        `${contractPath} compiled successfully, byte code length: ${byteCode.length}`
    );

    if (!byteCode.startsWith("0x")) {
        byteCode = `0x${byteCode}`;
    }

    return byteCode;
}

async function deployBytecode(
    hre: any,
    byteCode: string,
    name: string
): Promise<any> {
    const [signer] = await hre.ethers.getSigners();

    const tx = await signer.sendTransaction({ data: byteCode });
    const receipt = await tx.wait();

    log.debug(`${name} deploying, tx ${tx.hash}, waiting for confirmations`);

    if (receipt.status !== 1) {
        throw new Error(
            `failed to create ${name} contract, transaction ${tx.hash} reverted`
        );
    }

    return receipt.contractAddress;
}

async function getDeployer(hre: any) {
    const accounts = await hre.ethers.provider.listAccounts();
    if (accounts[0] !== undefined) {
        return accounts[0];
    }

    throw new Error(
        `Could not get account, check hardhat.config.ts: networks.${hre.network.name}.accounts`
    );
}

async function waitTx(hre: any, tx: any) {
    return tx.wait(hre.args.confirmations);
}

async function getContract(hre: any, abi: string[], contractAddress: string) {
    const signers = await hre.ethers.getSigners();

    if (!signers || signers.length === 0) {
        throw new Error(
            `Could not get account, check hardhat.config.ts. network: ${hre.network.name}`
        );
    }

    return new hre.ethers.Contract(contractAddress, abi, signers[0]);
}

function saveDeployments(_fileName: string, deployments: any) {
    const fileName = `deployments/${_fileName}.json`;
    fs.writeFileSync(fileName, JSON.stringify(deployments, undefined, 2));
    log.debug(`deployments saved to ${fileName}`);
}

function getDeployments(_fileName: string) {
    const fileName = `deployments/${_fileName}.json`;
    const json = fs.readFileSync(fileName);
    return JSON.parse(`${json}`);
}

async function decode(hre: any, type: any, data: any) {
    return hre.ethers.utils.defaultAbiCoder.decode([type], data).toString();
}

export {
    deployContract,
    compileYulContract,
    deployBytecode,
    getDeployer,
    waitTx,
    getContract,
    saveDeployments,
    getDeployments,
    decode,
};
