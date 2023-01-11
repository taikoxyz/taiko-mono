import * as fs from "fs";
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
    getDeployer,
    waitTx,
    getContract,
    saveDeployments,
    getDeployments,
    decode,
};
