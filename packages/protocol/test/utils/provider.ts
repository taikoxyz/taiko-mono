import { ethers } from "ethers";
// providers for integration tests

const getL1Provider = () =>
    new ethers.providers.JsonRpcProvider("http://localhost:18545");

const getL2Provider = () =>
    new ethers.providers.JsonRpcProvider("http://localhost:28545");

const getDefaultL1Signer = async () =>
    getL1Provider().getSigner((await getL1Provider().listAccounts())[0]);

const getDefaultL2Signer = async () =>
    getL2Provider().getSigner((await getL2Provider().listAccounts())[0]);

export { getL1Provider, getL2Provider, getDefaultL1Signer, getDefaultL2Signer };
