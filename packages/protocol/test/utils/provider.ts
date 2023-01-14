import { ethers } from "ethers";
// providers for integration tests

const getL1Provider = () =>
    new ethers.providers.JsonRpcProvider("http://localhost:18545");

const getL2Provider = () =>
    new ethers.providers.JsonRpcProvider("http://localhost:28545");

const getDefaultL2Signer = async () =>
    await getL2Provider().getSigner((await getL2Provider().listAccounts())[0]);

export { getL1Provider, getL2Provider, getDefaultL2Signer };
