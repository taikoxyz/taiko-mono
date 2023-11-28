import { ethers } from "ethers";
import { Result } from "./interface";
const path = require("path");
const ARTIFACTS_PATH = path.join(__dirname, "./usdc_deployed_bytecodes");

const {
    computeStorageSlots,
    getStorageLayout,
} = require("@defi-wonderland/smock/dist/src/utils");

export const TOKEN_NAME = "USD Coin";
export const TOKEN_SYMBOL = "USDC";
export const CURRENCY = "USD";
export const DECIMALS = 6;
export const THROWAWAY_ADDRESS = "0x0000000000000000000000000000000000000001";

// deployUSDC generates a L2 genesis alloc of circle's USDC contracts.
export async function deployUSDC(config: any, result: Result): Promise<Result> {
    const { contractOwner, chainId } = config;

    const alloc: any = {};
    const storageLayouts: any = {};

    const artifactTokenProxy = require(
        path.join(ARTIFACTS_PATH, "./FiatTokenProxy.sol/FiatTokenProxy.json"),
    );

    const artifactToken = require(
        path.join(ARTIFACTS_PATH, "./FiatTokenV2.sol/FiatTokenV2.json"),
    );

    artifactTokenProxy.contractName = "FiatTokenProxy";
    artifactToken.contractName = "FiatTokenV2";

    const addressProxy = ethers.utils.getCreate2Address(
        contractOwner,
        ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes(`${chainId}${artifactToken.contractName}`),
        ),
        ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes(artifactTokenProxy.bytecode),
        ),
    );

    const addressImpl = ethers.utils.getCreate2Address(
        contractOwner,
        ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes(`${chainId}${artifactToken.contracName}`),
        ),
        ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes(artifactToken.bytecode),
        ),
    );

    console.log("Proxy address:", addressProxy);
    console.log("Impl address:", addressImpl);

    const variables = {
        _owner: contractOwner,
        pauser: contractOwner,
        paused: 0,
        blacklister: contractOwner,
        name: TOKEN_NAME,
        symbol: TOKEN_SYMBOL,
        decimals: DECIMALS,
        currency: CURRENCY,
        masterMinter: contractOwner,
        initialized: 1,
        // minters: -> @David: One (default) shall be the ERC20Vault
        // minterAllowed: -> ERC20Vault shall be set to type(uint256).max i guess (?)
        _rescuer: contractOwner,
        DOMAIN_SEPARATOR:
            "0xfc500bb23f491a88aee347228b83d61b45a636871e666ef7be42535e06e2432c", // From USDC's GetDomainSeparator script, but needs to be changed to the proper chainId when deployed
        _initializedVersion: 2,
    };

    alloc[addressProxy] = {
        contractName: artifactTokenProxy.contractName,
        storage: {},
        code: artifactTokenProxy.deployedBytecode.object,
        balance: "0x0",
    };

    storageLayouts[artifactTokenProxy.contractName] = await getStorageLayout(
        artifactTokenProxy.contractName,
    );

    for (const slot of computeStorageSlots(
        storageLayouts[artifactTokenProxy.contractName],
        variables,
    )) {
        alloc[addressProxy].storage[slot.key] = slot.val;
    }

    result.alloc = Object.assign(result.alloc, alloc);
    result.storageLayouts = Object.assign(
        result.storageLayouts,
        storageLayouts,
    );

    return result;
}
