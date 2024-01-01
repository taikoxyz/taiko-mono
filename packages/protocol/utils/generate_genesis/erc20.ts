import { ethers } from "ethers";
import { Result } from "./interface";
const path = require("path");
const ARTIFACTS_PATH = path.join(__dirname, "../../out");
const { computeStorageSlots, getStorageLayout } = require("./utils");

export const TOKEN_NAME = "RegularERC20";
export const TOKEN_SYMBOL = "RGL";
export const PREMINT_SEED_ACCOUNT_BALANCE = ethers.BigNumber.from(1024000);

// deployERC20 generates a L2 genesis alloc of an ERC-20 contract,
// and premints some tokens for the seed accounts given in the configurations.
export async function deployERC20(
    config: any,
    result: Result,
): Promise<Result> {
    const { contractOwner, chainId, seedAccounts } = config;

    const alloc: any = {};
    const storageLayouts: any = {};

    const artifact = require(
        path.join(ARTIFACTS_PATH, "./RegularERC20.sol/RegularERC20.json"),
    );

    artifact.contractName = "RegularERC20";

    let address: string;
    if (
        config.contractAddresses &&
        ethers.utils.isAddress(config.contractAddresses[artifact.contractName])
    ) {
        address = config.contractAddresses[artifact.contractName];
    } else {
        address = ethers.utils.getCreate2Address(
            contractOwner,
            ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes(`${chainId}${artifact.contractName}`),
            ),
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes(artifact.bytecode)),
        );
    }

    const variables = {
        _name: TOKEN_NAME,
        _symbol: TOKEN_SYMBOL,
        _totalSupply: PREMINT_SEED_ACCOUNT_BALANCE.mul(seedAccounts.length),
        _balances: {} as any,
    };

    for (const account of seedAccounts) {
        variables._balances[Object.keys(account)[0]] =
            PREMINT_SEED_ACCOUNT_BALANCE;
    }

    alloc[address] = {
        contractName: artifact.contractName,
        storage: {},
        code: artifact.deployedBytecode.object,
        balance: "0x0",
    };

    storageLayouts[artifact.contractName] = await getStorageLayout(
        artifact.contractName,
    );

    for (const slot of computeStorageSlots(
        storageLayouts[artifact.contractName],
        variables,
    )) {
        alloc[address].storage[slot.key] = slot.val;
    }

    result.alloc = Object.assign(result.alloc, alloc);
    result.storageLayouts = Object.assign(
        result.storageLayouts,
        storageLayouts,
    );

    return result;
}
